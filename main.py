"""Tapo L530 smart bulb wrapper.

Wraps the synchronous PyP100/PyL530 client. All blocking calls are guarded by a
per-device lock; the API layer runs them in a thread executor so the event loop
never blocks.
"""
import threading
from typing import Optional

try:
    from PyP100 import PyL530
except Exception:  # pragma: no cover - lib only present on the target host
    PyL530 = None


class LedDevice:
    def __init__(self, ip: str, email: str, password: str, name: Optional[str] = None):
        if PyL530 is None:
            raise RuntimeError(
                "PyP100 not installed. Install: "
                "pip install git+https://github.com/almottier/TapoP100.git"
            )
        self.ip = ip
        self.name = name or f"LED {ip}"
        self._lock = threading.Lock()
        self._bulb = PyL530.L530(ip, email, password)
        self._connect()
        # cached state for the UI (the lib has no reliable getters across forks)
        self.state = {
            "on": False,
            "brightness": 100,
            "hue": None,
            "saturation": None,
            "color_temp": 2700,
        }

    def _connect(self):
        self._bulb.handshake()
        self._bulb.login()

    def _reconnect_and(self, fn):
        """Tapo sessions expire; retry once after a fresh handshake/login."""
        try:
            return fn()
        except Exception:
            self._connect()
            return fn()

    # ---- controls ----
    def turn_on(self):
        with self._lock:
            self._reconnect_and(self._bulb.turnOn)
            self.state["on"] = True

    def turn_off(self):
        with self._lock:
            self._reconnect_and(self._bulb.turnOff)
            self.state["on"] = False

    def set_brightness(self, brightness: int):
        with self._lock:
            self._reconnect_and(lambda: self._bulb.setBrightness(brightness))
            self.state["brightness"] = brightness

    def set_color(self, hue: int, saturation: int):
        with self._lock:
            self._reconnect_and(lambda: self._bulb.setColor(hue, saturation))
            self.state.update(hue=hue, saturation=saturation)

    def set_color_temp(self, temp: int):
        with self._lock:
            self._reconnect_and(lambda: self._bulb.setColorTemp(temp))
            self.state.update(color_temp=temp, hue=None, saturation=None)

    def info(self) -> dict:
        return {"ip": self.ip, "name": self.name, "type": "led", "state": self.state}
