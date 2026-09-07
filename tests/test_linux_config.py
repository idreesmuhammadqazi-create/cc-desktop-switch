import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend import registry
from backend import main as backend_main
from backend import update as updater
from backend import config as cfg
import main as app_main


class LinuxConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.xdg_config = os.path.join(self.temp_dir.name, "config")
        self.xdg_data = os.path.join(self.temp_dir.name, "data")
        os.makedirs(self.xdg_config, exist_ok=True)
        os.makedirs(self.xdg_data, exist_ok=True)

        self.claude_dir = os.path.join(self.xdg_config, "Claude")
        self.claude_json = os.path.join(self.claude_dir, "claude_desktop_config.json")
        self.library_dir = os.path.join(self.claude_dir, "configLibrary")

    def test_linux_apply_config_creates_config_and_library(self):
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": self.xdg_config}):
            with patch.object(registry, "LINUX_CLAUDE_CONFIG", self.claude_json):
                with patch.object(registry, "LINUX_3P_CONFIG", os.path.join(self.xdg_config, "Claude-3p", "claude_desktop_config.json")):
                    result = registry._linux_apply_config(
                        "http://127.0.0.1:18080",
                        gateway_api_key="sk-test-key",
                        inference_models='[{"name":"claude-3-5-sonnet-20241022","displayName":"Sonnet"}]',
                        auth_scheme="bearer",
                        gateway_headers='["X-Custom: Value"]',
                    )

        self.assertTrue(result["success"])
        self.assertTrue(os.path.exists(self.claude_json))

        with open(self.claude_json, "r", encoding="utf-8") as handle:
            data = json.load(handle)

        self.assertEqual(data.get("deploymentMode"), "3p")
        enterprise = data.get("enterpriseConfig", {})
        self.assertEqual(enterprise.get("inferenceProvider"), "gateway")
        self.assertEqual(enterprise.get("inferenceGatewayBaseUrl"), "http://127.0.0.1:18080")
        self.assertEqual(enterprise.get("inferenceGatewayApiKey"), "sk-test-key")
        self.assertEqual(enterprise.get("inferenceGatewayAuthScheme"), "bearer")
        self.assertEqual(enterprise.get("inferenceGatewayHeaders"), ["X-Custom: Value"])
        self.assertIn("Sonnet", str(enterprise.get("inferenceModels")))

        # Check configLibrary
        meta_file = os.path.join(self.library_dir, "_meta.json")
        self.assertTrue(os.path.exists(meta_file))
        with open(meta_file, "r", encoding="utf-8") as handle:
            meta = json.load(handle)
        applied_id = meta["appliedId"]
        self.assertTrue(applied_id)

        entry_file = os.path.join(self.library_dir, f"{applied_id}.json")
        self.assertTrue(os.path.exists(entry_file))
        with open(entry_file, "r", encoding="utf-8") as handle:
            entry = json.load(handle)
        self.assertEqual(entry.get("inferenceProvider"), "gateway")
        self.assertEqual(entry.get("inferenceGatewayBaseUrl"), "http://127.0.0.1:18080")

    def test_linux_apply_config_preserves_existing_user_settings(self):
        os.makedirs(self.claude_dir, exist_ok=True)
        initial_data = {
            "mcpServers": {
                "fetch": {"command": "uvx", "args": ["mcp-server-fetch"]}
            },
            "customSetting": "preserved",
        }
        with open(self.claude_json, "w", encoding="utf-8") as handle:
            json.dump(initial_data, handle)

        with patch.dict(os.environ, {"XDG_CONFIG_HOME": self.xdg_config}):
            with patch.object(registry, "LINUX_CLAUDE_CONFIG", self.claude_json):
                with patch.object(registry, "LINUX_3P_CONFIG", os.path.join(self.xdg_config, "Claude-3p", "claude_desktop_config.json")):
                    result = registry._linux_apply_config("http://127.0.0.1:18080")

        self.assertTrue(result["success"])
        with open(self.claude_json, "r", encoding="utf-8") as handle:
            data = json.load(handle)

        self.assertEqual(data.get("deploymentMode"), "3p")
        self.assertIn("fetch", data.get("mcpServers", {}))
        self.assertEqual(data.get("customSetting"), "preserved")

    def test_linux_get_config_status_and_clear(self):
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": self.xdg_config}):
            with patch.object(registry, "LINUX_CLAUDE_CONFIG", self.claude_json):
                with patch.object(registry, "LINUX_3P_CONFIG", os.path.join(self.xdg_config, "Claude-3p", "claude_desktop_config.json")):
                    # Unconfigured initially
                    status = registry._linux_get_config_status()
                    self.assertFalse(status["configured"])

                    # Apply
                    registry._linux_apply_config("http://127.0.0.1:18080", gateway_api_key="secret")
                    status_after = registry._linux_get_config_status()
                    self.assertTrue(status_after["configured"])
                    self.assertEqual(status_after["keys"]["inferenceGatewayBaseUrl"], "http://127.0.0.1:18080")

                    # Clear
                    clear_res = registry._linux_clear_config()
                    self.assertTrue(clear_res["success"])

                    status_cleared = registry._linux_get_config_status()
                    self.assertFalse(status_cleared["configured"])

    def test_registry_routes_linux_platform(self):
        with patch("backend.registry._os_name", return_value="linux"):
            with patch("backend.registry._linux_get_config_status", return_value={"configured": True, "keys": {}}) as mock_status:
                status = registry.get_config_status()
                self.assertTrue(status["configured"])
                mock_status.assert_called_once()

            with patch("backend.registry._linux_apply_config", return_value={"success": True, "message": "applied"}) as mock_apply:
                res = registry.apply_config("http://127.0.0.1:18080")
                self.assertTrue(res["success"])
                mock_apply.assert_called_once()

            with patch("backend.registry._linux_clear_config", return_value={"success": True, "message": "cleared"}) as mock_clear:
                res = registry.clear_config()
                self.assertTrue(res["success"])
                mock_clear.assert_called_once()

    def test_claude_code_helper_candidates_linux(self):
        helper_bin = os.path.join(self.xdg_config, "Claude", "claude-code", "v1", "claude")
        os.makedirs(os.path.dirname(helper_bin), exist_ok=True)
        Path(helper_bin).touch()

        with patch("sys.platform", "linux"):
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": self.xdg_config, "XDG_DATA_HOME": self.xdg_data}):
                candidates = backend_main._claude_code_helper_candidates()
                self.assertIn(Path(helper_bin), candidates)

    def test_linux_single_instance_locking(self):
        with patch("sys.platform", "linux"):
            with patch.object(cfg, "CONFIG_DIR", self.temp_dir.name):
                # First acquire succeeds
                acquired1 = app_main.acquire_single_instance_lock()
                self.assertTrue(acquired1)

                # Second acquire fails (simulating another process on same lock)
                import fcntl
                test_fd = open(os.path.join(self.temp_dir.name, "app.lock"), "a+")
                with self.assertRaises((BlockingIOError, OSError)):
                    fcntl.flock(test_fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                test_fd.close()

                # Release
                app_main.release_single_instance_lock()

                # After release, acquire succeeds again
                acquired2 = app_main.acquire_single_instance_lock()
                self.assertTrue(acquired2)
                app_main.release_single_instance_lock()

    def test_update_installer_linux(self):
        assets = [
            {"name": "CC-Desktop-Switch-v1.0.26-linux-x64.tar.gz"},
            {"name": "CC-Desktop-Switch-v1.0.26-x86_64.AppImage"},
            {"name": "CC-Desktop-Switch-v1.0.26-amd64.deb"},
        ]
        # Priority: AppImage first
        picked = updater.pick_platform_installer(assets, "linux-x64")
        self.assertEqual(picked["name"], "CC-Desktop-Switch-v1.0.26-x86_64.AppImage")

        # Without AppImage, deb or tar.gz
        assets_without_appimage = [
            {"name": "CC-Desktop-Switch-v1.0.26-amd64.deb"},
            {"name": "CC-Desktop-Switch-v1.0.26-linux-x64.tar.gz"},
        ]
        picked2 = updater.pick_platform_installer(assets_without_appimage, "linux-x64")
        self.assertEqual(picked2["name"], "CC-Desktop-Switch-v1.0.26-amd64.deb")

        # Install command
        cmd = updater.install_command("/tmp/update.AppImage", "linux-x64")
        self.assertEqual(cmd, ["xdg-open", "/tmp/update.AppImage"])


if __name__ == "__main__":
    unittest.main()
