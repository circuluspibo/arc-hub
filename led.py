"""Xiaomi Air Purifier 4 Lite wrapper (python-miio).

The miio client is synchronous. Calls are serialized per-device with a lock and
executed in a thread pool by the API layer.
"""
import threading
from typing import Optional

try:
    from miio import DeviceFactory
    from miio.integrations.zhimi.airpurifier.airpurifier_miot import (
        OperationMode,
        LedBrightness,
    )
except Exception:  # pragma: no cover - lib only present on the target host
    DeviceFactory = None
    OperationMode = None
    LedBrightness = None


class AirDevice:
    def __init__(self, ip: str, token: str, name: Optional[str] = None):
        if DeviceFactory is None:
            raise RuntimeError("python-miio not installed. Install: pip install python-miio")
        self.ip = ip
        self.name = name or f"Air {ip}"
        self.token = token
        self._lock = threading.Lock()
        self._dev = DeviceFactory.create(ip, token)
        # verify reachable
        self._dev.status()

    # ---- read ----
    def status(self) -> dict:
        with self._lock:
            s = self._dev.status()
        return {
            "on": bool(s.is_on),
            "aqi": getattr(s, "aqi", None),
            "temperature": getattr(s, "temperature", None),
            "humidity": getattr(s, "humidity", None),
            "mode": str(getattr(s, "mode", "")).split(".")[-1],
            "anion": getattr(s, "anion", None),
            "motor_speed": getattr(s, "motor_speed", None),
            "filter_life_remaining": getattr(s, "filter_life_remaining", None),
            "filter_hours_used": getattr(s, "filter_hours_used", None),
            "child_lock": getattr(s, "child_lock", None),
            "buzzer": getattr(s, "buzzer", None),
        }

    # ---- controls ----
    def set_power(self, on: bool):
        with self._lock:
            self._dev.on() if on else self._dev.off()

    def set_mode(self, mode: str):
        with self._lock:
            self._dev.set_mode(OperationMode[mode])

    def set_favorite_level(self, level: int):
        with self._lock:
            self._dev.set_favorite_level(level)

    def set_led_brightness(self, brightness: str):
        with self._lock:
            self._dev.set_led_brightness(LedBrightness[brightness])

    def set_anion(self, on: bool):
        with self._lock:
            self._dev.set_anion(on)

    def set_buzzer(self, on: bool):
        with self._lock:
            self._dev.set_buzzer(on)

    def set_child_lock(self, on: bool):
        with self._lock:
            self._dev.set_child_lock(on)

    def info(self) -> dict:
        return {"ip": self.ip, "name": self.name, "type": "air"}
