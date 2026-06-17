"""A small device registry. Each device type keeps its own dict keyed by IP."""
import threading
from typing import Dict, Generic, TypeVar, Optional, List

T = TypeVar("T")


class Registry(Generic[T]):
    """Thread-safe IP-keyed store of device instances."""

    def __init__(self, kind: str):
        self.kind = kind
        self._items: Dict[str, T] = {}
        self._lock = threading.RLock()

    def add(self, ip: str, device: T) -> T:
        with self._lock:
            self._items[ip] = device
            return device

    def get(self, ip: str) -> Optional[T]:
        with self._lock:
            return self._items.get(ip)

    def require(self, ip: str) -> T:
        dev = self.get(ip)
        if dev is None:
            raise KeyError(f"{self.kind} device '{ip}' is not registered")
        return dev

    def remove(self, ip: str) -> bool:
        with self._lock:
            return self._items.pop(ip, None) is not None

    def keys(self) -> List[str]:
        with self._lock:
            return list(self._items.keys())

    def values(self) -> List[T]:
        with self._lock:
            return list(self._items.values())

    def __contains__(self, ip: str) -> bool:
        with self._lock:
            return ip in self._items
