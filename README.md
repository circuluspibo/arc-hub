"""WebRTC bridge for CCTV.

- CameraVideoTrack: an aiortc VideoStreamTrack that emits the camera's latest
  RTSP frame at a fixed rate.
- create_peer_connection: builds an RTCPeerConnection, attaches the track, wires
  a "ptz" data channel so the browser can steer the camera over WebRTC, and
  answers the browser's SDP offer.

No external/STUN servers are configured, so negotiation stays on the LAN.
"""
import asyncio
import fractions
import json
import time
from typing import Set

import av
import numpy as np
from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack
from aiortc.contrib.media import MediaBlackhole

from .devices.cctv import CctvDevice

VIDEO_CLOCK_RATE = 90000
VIDEO_FPS = 20
VIDEO_PTIME = 1 / VIDEO_FPS

pcs: Set[RTCPeerConnection] = set()


class CameraVideoTrack(VideoStreamTrack):
    kind = "video"

    def __init__(self, camera: CctvDevice):
        super().__init__()
        self.camera = camera
        self.camera.acquire_viewer()
        self._start = time.time()
        self._timestamp = 0
        self._placeholder = np.zeros((360, 640, 3), dtype=np.uint8)

    async def recv(self):
        # pace frames to VIDEO_FPS
        self._timestamp += int(VIDEO_PTIME * VIDEO_CLOCK_RATE)
        wait = self._start + (self._timestamp / VIDEO_CLOCK_RATE) - time.time()
        if wait > 0:
            await asyncio.sleep(wait)

        frame = await asyncio.get_event_loop().run_in_executor(
            None, self.camera.get_frame
        )
        if frame is None:
            frame = self._placeholder

        video_frame = av.VideoFrame.from_ndarray(frame, format="bgr24")
        video_frame.pts = self._timestamp
        video_frame.time_base = fractions.Fraction(1, VIDEO_CLOCK_RATE)
        return video_frame

    def stop(self):
        super().stop()
        try:
            self.camera.release_viewer()
        except Exception:
            pass


async def create_peer_connection(camera: CctvDevice, offer: RTCSessionDescription):
    pc = RTCPeerConnection()  # no ICE servers -> LAN/host candidates only
    pcs.add(pc)
    track = CameraVideoTrack(camera)
    pc.addTrack(track)

    @pc.on("datachannel")
    def on_datachannel(channel):
        @channel.on("message")
        def on_message(message):
            try:
                cmd = json.loads(message)
            except Exception:
                return
            if cmd.get("action") == "move":
                x = float(cmd.get("x", 0))
                y = float(cmd.get("y", 0))
                dur = float(cmd.get("duration", 0.4))
                # PTZ blocks; run it off the event loop
                asyncio.get_event_loop().run_in_executor(
                    None, camera.move, x, y, dur
                )
                try:
                    channel.send(json.dumps({"ack": "move", "x": x, "y": y}))
                except Exception:
                    pass

    @pc.on("connectionstatechange")
    async def on_state():
        if pc.connectionState in ("failed", "closed", "disconnected"):
            track.stop()
            await pc.close()
            pcs.discard(pc)

    await pc.setRemoteDescription(offer)
    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    return pc.localDescription


async def shutdown():
    coros = [pc.close() for pc in pcs]
    await asyncio.gather(*coros, return_exceptions=True)
    pcs.clear()
