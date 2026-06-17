"""Unified local IoT control API.

Runs entirely on the LAN. Three device types — Tapo LED bulbs, Xiaomi air
purifiers, and ONVIF/RTSP CCTV — are each registered by IP and controlled
through REST. CCTV video + PTZ also stream over WebRTC.

Run:  uvicorn app.main:app --host 0.0.0.0 --port 8000
"""
import asyncio
from pathlib import Path

from fastapi import FastAPI, HTTPException, APIRouter, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from aiortc import RTCSessionDescription

from . import schemas
from .devices.registry import Registry
from .devices.led import LedDevice
from .devices.air import AirDevice
from .devices.cctv import CctvDevice
from . import webrtc

app = FastAPI(title="Local IoT Hub", version="1.0.0")

led_reg: Registry[LedDevice] = Registry("led")
air_reg: Registry[AirDevice] = Registry("air")
cctv_reg: Registry[CctvDevice] = Registry("cctv")

STATIC_DIR = Path(__file__).resolve().parent.parent / "static"


@app.exception_handler(KeyError)
async def _key_error_handler(request: Request, exc: KeyError):
    # registry.require() raises KeyError for unknown device IPs
    return JSONResponse(status_code=404, content={"detail": str(exc).strip('"')})


async def run_blocking(fn, *args):
    """Execute a blocking device call in a thread, surface errors as HTTP 502."""
    try:
        return await asyncio.get_event_loop().run_in_executor(None, fn, *args)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"device error: {e}")


# ============================================================
# LED router
# ============================================================
led = APIRouter(prefix="/api/led", tags=["led"])


@led.post("/register", response_model=schemas.OkResponse)
async def led_register(body: schemas.LedRegister):
    def _make():
        dev = LedDevice(body.ip, body.email, body.password, body.name)
        led_reg.add(body.ip, dev)
        return dev
    await run_blocking(_make)
    return schemas.OkResponse(detail=f"LED {body.ip} registered")


@led.get("/list")
async def led_list():
    return [d.info() for d in led_reg.values()]


@led.delete("/{ip}", response_model=schemas.OkResponse)
async def led_delete(ip: str):
    removed = led_reg.remove(ip)
    if not removed:
        raise HTTPException(404, f"led '{ip}' not found")
    return schemas.OkResponse(detail=f"LED {ip} removed")


@led.post("/{ip}/power", response_model=schemas.OkResponse)
async def led_power(ip: str, body: schemas.LedPower):
    dev = led_reg.require(ip)
    await run_blocking(dev.turn_on if body.on else dev.turn_off)
    return schemas.OkResponse(detail=f"LED {'on' if body.on else 'off'}")


@led.post("/{ip}/brightness", response_model=schemas.OkResponse)
async def led_brightness(ip: str, body: schemas.LedBrightness):
    dev = led_reg.require(ip)
    await run_blocking(dev.set_brightness, body.brightness)
    return schemas.OkResponse(detail=f"brightness {body.brightness}%")


@led.post("/{ip}/color", response_model=schemas.OkResponse)
async def led_color(ip: str, body: schemas.LedColor):
    dev = led_reg.require(ip)
    await run_blocking(dev.set_color, body.hue, body.saturation)
    return schemas.OkResponse(detail=f"color H{body.hue} S{body.saturation}")


@led.post("/{ip}/color_temp", response_model=schemas.OkResponse)
async def led_color_temp(ip: str, body: schemas.LedColorTemp):
    dev = led_reg.require(ip)
    await run_blocking(dev.set_color_temp, body.temp)
    return schemas.OkResponse(detail=f"{body.temp}K")


# ============================================================
# Air purifier router
# ============================================================
air = APIRouter(prefix="/api/air", tags=["air"])


@air.post("/register", response_model=schemas.OkResponse)
async def air_register(body: schemas.AirRegister):
    def _make():
        dev = AirDevice(body.ip, body.token, body.name)
        air_reg.add(body.ip, dev)
        return dev
    await run_blocking(_make)
    return schemas.OkResponse(detail=f"Air {body.ip} registered")


@air.get("/list")
async def air_list():
    return [d.info() for d in air_reg.values()]


@air.delete("/{ip}", response_model=schemas.OkResponse)
async def air_delete(ip: str):
    if not air_reg.remove(ip):
        raise HTTPException(404, f"air '{ip}' not found")
    return schemas.OkResponse(detail=f"Air {ip} removed")


@air.get("/{ip}/status")
async def air_status(ip: str):
    dev = air_reg.require(ip)
    return await run_blocking(dev.status)


@air.post("/{ip}/power", response_model=schemas.OkResponse)
async def air_power(ip: str, body: schemas.AirPower):
    dev = air_reg.require(ip)
    await run_blocking(dev.set_power, body.on)
    return schemas.OkResponse(detail=f"power {'on' if body.on else 'off'}")


@air.post("/{ip}/mode", response_model=schemas.OkResponse)
async def air_mode(ip: str, body: schemas.AirMode):
    dev = air_reg.require(ip)
    await run_blocking(dev.set_mode, body.mode)
    return schemas.OkResponse(detail=f"mode {body.mode}")


@air.post("/{ip}/favorite_level", response_model=schemas.OkResponse)
async def air_favorite(ip: str, body: schemas.AirFavoriteLevel):
    dev = air_reg.require(ip)
    await run_blocking(dev.set_favorite_level, body.level)
    return schemas.OkResponse(detail=f"favorite level {body.level}")


@air.post("/{ip}/led", response_model=schemas.OkResponse)
async def air_led(ip: str, body: schemas.AirLedBrightness):
    dev = air_reg.require(ip)
    await run_blocking(dev.set_led_brightness, body.brightness)
    return schemas.OkResponse(detail=f"led {body.brightness}")


@air.post("/{ip}/anion", response_model=schemas.OkResponse)
async def air_anion(ip: str, body: schemas.AirToggle):
    dev = air_reg.require(ip)
    await run_blocking(dev.set_anion, body.on)
    return schemas.OkResponse(detail=f"anion {body.on}")


@air.post("/{ip}/buzzer", response_model=schemas.OkResponse)
async def air_buzzer(ip: str, body: schemas.AirToggle):
    dev = air_reg.require(ip)
    await run_blocking(dev.set_buzzer, body.on)
    return schemas.OkResponse(detail=f"buzzer {body.on}")


@air.post("/{ip}/child_lock", response_model=schemas.OkResponse)
async def air_child_lock(ip: str, body: schemas.AirToggle):
    dev = air_reg.require(ip)
    await run_blocking(dev.set_child_lock, body.on)
    return schemas.OkResponse(detail=f"child_lock {body.on}")


# ============================================================
# CCTV router (REST PTZ + WebRTC)
# ============================================================
cctv = APIRouter(prefix="/api/cctv", tags=["cctv"])


@cctv.post("/register", response_model=schemas.OkResponse)
async def cctv_register(body: schemas.CctvRegister):
    def _make():
        dev = CctvDevice(
            body.ip, body.user, body.password,
            rtsp_port=body.rtsp_port, onvif_port=body.onvif_port,
            stream=body.stream, name=body.name,
        )
        cctv_reg.add(body.ip, dev)
        return dev
    await run_blocking(_make)
    return schemas.OkResponse(detail=f"CCTV {body.ip} registered")


@cctv.get("/list")
async def cctv_list():
    return [d.info() for d in cctv_reg.values()]


@cctv.delete("/{ip}", response_model=schemas.OkResponse)
async def cctv_delete(ip: str):
    dev = cctv_reg.get(ip)
    if dev is None:
        raise HTTPException(404, f"cctv '{ip}' not found")
    dev.stop()
    cctv_reg.remove(ip)
    return schemas.OkResponse(detail=f"CCTV {ip} removed")


@cctv.post("/{ip}/move", response_model=schemas.OkResponse)
async def cctv_move(ip: str, body: schemas.CctvMove):
    """REST fallback for PTZ (WebRTC data channel is the primary path)."""
    dev = cctv_reg.require(ip)
    await run_blocking(dev.move, body.x, body.y, body.duration)
    return schemas.OkResponse(detail=f"moved x={body.x} y={body.y}")


@cctv.post("/{ip}/webrtc")
async def cctv_webrtc(ip: str, offer: schemas.WebRTCOffer):
    """Accept a browser SDP offer, return the answer. Video + PTZ data channel."""
    dev = cctv_reg.require(ip)
    rtc_offer = RTCSessionDescription(sdp=offer.sdp, type=offer.type)
    answer = await webrtc.create_peer_connection(dev, rtc_offer)
    return {"sdp": answer.sdp, "type": answer.type}


# ============================================================
# Wire up
# ============================================================
app.include_router(led)
app.include_router(air)
app.include_router(cctv)


@app.get("/api/health")
async def health():
    return {
        "ok": True,
        "devices": {
            "led": led_reg.keys(),
            "air": air_reg.keys(),
            "cctv": cctv_reg.keys(),
        },
    }


@app.on_event("shutdown")
async def _shutdown():
    await webrtc.shutdown()
    for d in cctv_reg.values():
        d.stop()


# static site (mounted last so /api/* wins)
app.mount("/", StaticFiles(directory=str(STATIC_DIR), html=True), name="static")
