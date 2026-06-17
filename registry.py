"""CCTV wrapper: ONVIF PTZ control + a shared RTSP frame reader for WebRTC.

One background thread per camera reads RTSP frames into a single shared "latest
frame" slot. Every WebRTC viewer track reads from that slot, so N viewers cost
only one RTSP connection. PTZ uses ONVIF ContinuousMove + Stop.
"""
import threading
import time
from typing import Optional

import cv2

try:
    from onvif import ONVIFCamera
except Exception:  # pragma: no cover
    ONVIFCamera = None


class CctvDevice:
    def __init__(
        self,
        ip: str,
        user: str,
        password: str,
        rtsp_port: int = 554,
        onvif_port: int = 2020,
        stream: str = "stream1",
        name: Optional[str] = None,
    ):
        self.ip = ip
        self.name = name or f"CCTV {ip}"
        self.user = user
        self.password = password
        self.rtsp_url = f"rtsp://{user}:{password}@{ip}:{rtsp_port}/{stream}"

        # --- shared frame buffer ---
        self._frame = None  # latest BGR numpy frame
        self._frame_lock = threading.Lock()
        self._running = False
        self._reader: Optional[threading.Thread] = None
        self._viewers = 0
        self._viewers_lock = threading.Lock()

        # --- ONVIF / PTZ ---
        self.ptz = None
        self.profile_token = None
        self._ptz_lock = threading.Lock()
        self._ptz_error: Optional[str] = None
        self._init_ptz(onvif_port)

    # ---------------- ONVIF PTZ ----------------
    def _init_ptz(self, onvif_port: int):
        if ONVIFCamera is None:
            self._ptz_error = "onvif-zeep not installed"
            return
        try:
            cam = ONVIFCamera(self.ip, onvif_port, self.user, self.password)
            self.ptz = cam.create_ptz_service()
            media = cam.create_media_service()
            profile = media.GetProfiles()[0]
            self.profile_token = profile.token
            req = self.ptz.create_type("GetConfigurationOptions")
            req.ConfigurationToken = profile.PTZConfiguration.token
            self.ptz.GetConfigurationOptions(req)
        except Exception as e:
            self.ptz = None
            self._ptz_error = str(e)

    def move(self, x: float, y: float, duration: float = 0.4):
        if self.ptz is None:
            raise RuntimeError(f"PTZ unavailable: {self._ptz_error}")
        with self._ptz_lock:
            req = self.ptz.create_type("ContinuousMove")
            req.ProfileToken = self.profile_token
            status = self.ptz.GetStatus({"ProfileToken": self.profile_token})
            req.Velocity = status.Position
            req.Velocity.PanTilt.x = x
            req.Velocity.PanTilt.y = y
            self.ptz.ContinuousMove(req)
            time.sleep(duration)
            self.ptz.Stop(
                {"ProfileToken": self.profile_token, "PanTilt": True, "Zoom": False}
            )

    # ---------------- RTSP reader ----------------
    def _read_loop(self):
        cap = cv2.VideoCapture(self.rtsp_url, cv2.CAP_FFMPEG)
        try:
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        except Exception:
            pass
        backoff = 1.0
        while self._running:
            if not cap.isOpened():
                time.sleep(backoff)
                cap.release()
                cap = cv2.VideoCapture(self.rtsp_url, cv2.CAP_FFMPEG)
                backoff = min(backoff * 2, 10)
                continue
            ok, frame = cap.read()
            if not ok:
                cap.release()
                cap = cv2.VideoCapture(self.rtsp_url, cv2.CAP_FFMPEG)
                time.sleep(0.5)
                continue
            backoff = 1.0
            with self._frame_lock:
                self._frame = frame
        cap.release()

    def _ensure_reader(self):
        if self._running:
            return
        self._running = True
        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()

    def acquire_viewer(self):
        with self._viewers_lock:
            self._viewers += 1
            self._ensure_reader()

    def release_viewer(self):
        with self._viewers_lock:
            self._viewers = max(0, self._viewers - 1)
            if self._viewers == 0:
                self._running = False  # reader loop exits, RTSP released

    def get_frame(self):
        with self._frame_lock:
            return None if self._frame is None else self._frame.copy()

    def stop(self):
        self._running = False

    def info(self) -> dict:
        return {
            "ip": self.ip,
            "name": self.name,
            "type": "cctv",
            "rtsp_url": self.rtsp_url.replace(self.password, "****"),
            "ptz": self.ptz is not None,
            "ptz_error": self._ptz_error,
            "viewers": self._viewers,
        }
