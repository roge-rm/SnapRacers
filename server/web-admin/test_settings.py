import asyncio
import unittest
from unittest.mock import patch

from app import main


class SettingsFormTest(unittest.TestCase):
    def test_layout_checkboxes_save_on_and_unchecked_off(self):
        class Request:
            async def form(self):
                return {"csrf": "token", "reversed": "on"}

        class Control:
            def __init__(self):
                self.values = {"reversed": False, "mirrored": True}
                self.changed = []

            def status(self):
                return {"config": self.values}

            def set(self, name, value):
                self.changed.append((name, value))
                return {}

        control = Control()
        with patch.object(main, "control", control), patch.object(main, "guard", return_value=None):
            asyncio.run(main.save_settings(Request()))

        self.assertEqual(control.changed, [("reversed", "true"), ("mirrored", "false")])


if __name__ == "__main__":
    unittest.main()
