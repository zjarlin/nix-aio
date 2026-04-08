#!/usr/bin/env python3
import json
import os
import re
import subprocess
import threading
import urllib.error
import urllib.request

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import GLib, Gtk


EXECUTOR_BIN = os.environ.get("EXECUTOR_BIN", "niri-installer-executor")
LOG_FILE = os.environ.get("INSTALLER_LOG_FILE", "/var/log/niri-installer.log")
USERNAME_RE = re.compile(r"^[a-z_][a-z0-9_-]{0,30}$")


def run_command(command):
    return subprocess.run(command, check=False, capture_output=True, text=True)


class InstallerWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Niri Installer")
        self.set_default_size(1280, 800)
        self.fullscreen()

        self.disks = []
        self.install_thread = None

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        root.set_margin_top(32)
        root.set_margin_bottom(32)
        root.set_margin_start(48)
        root.set_margin_end(48)

        title = Gtk.Label(label="NixOS + Niri Installer")
        title.add_css_class("title-1")
        title.set_xalign(0.0)
        root.append(title)

        subtitle = Gtk.Label(
            label="This installer connects networking, collects one user account, wipes a chosen disk, and installs NixOS with Niri.",
        )
        subtitle.set_wrap(True)
        subtitle.set_xalign(0.0)
        root.append(subtitle)

        self.stack = Gtk.Stack()
        self.stack.set_hexpand(True)
        self.stack.set_vexpand(True)
        root.append(self.stack)

        self.network_page = self.build_network_page()
        self.account_page = self.build_account_page()
        self.disk_page = self.build_disk_page()
        self.confirm_page = self.build_confirm_page()
        self.install_page = self.build_install_page()

        self.stack.add_named(self.network_page, "network")
        self.stack.add_named(self.account_page, "account")
        self.stack.add_named(self.disk_page, "disk")
        self.stack.add_named(self.confirm_page, "confirm")
        self.stack.add_named(self.install_page, "install")

        self.set_child(root)
        self.go_to_network_gate()

    def build_page_shell(self, heading_text, body_text):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_hexpand(True)
        box.set_vexpand(True)

        heading = Gtk.Label(label=heading_text)
        heading.add_css_class("title-2")
        heading.set_xalign(0.0)
        box.append(heading)

        body = Gtk.Label(label=body_text)
        body.set_wrap(True)
        body.set_xalign(0.0)
        box.append(body)

        return box

    def build_network_page(self):
        box = self.build_page_shell(
            "Step 1: Connect networking",
            "The installer will not continue until it can reach the Nix binary cache.",
        )

        self.network_status = Gtk.Label(label="")
        self.network_status.set_wrap(True)
        self.network_status.set_xalign(0.0)
        box.append(self.network_status)

        button_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        open_button = Gtk.Button(label="Open Network Settings")
        open_button.connect("clicked", self.on_open_network_settings)
        button_row.append(open_button)

        retry_button = Gtk.Button(label="Retry")
        retry_button.connect("clicked", self.on_retry_network)
        button_row.append(retry_button)

        box.append(button_row)
        return box

    def build_account_page(self):
        box = self.build_page_shell(
            "Step 2: Create the primary user",
            "This account becomes the first admin user on the installed system.",
        )

        form = Gtk.Grid(column_spacing=12, row_spacing=12)
        form.set_hexpand(False)

        username_label = Gtk.Label(label="Username")
        username_label.set_xalign(0.0)
        form.attach(username_label, 0, 0, 1, 1)

        self.username_entry = Gtk.Entry()
        self.username_entry.set_text("niri")
        form.attach(self.username_entry, 1, 0, 1, 1)

        password_label = Gtk.Label(label="Password")
        password_label.set_xalign(0.0)
        form.attach(password_label, 0, 1, 1, 1)

        self.password_entry = Gtk.Entry()
        self.password_entry.set_visibility(False)
        form.attach(self.password_entry, 1, 1, 1, 1)

        password_confirm_label = Gtk.Label(label="Confirm password")
        password_confirm_label.set_xalign(0.0)
        form.attach(password_confirm_label, 0, 2, 1, 1)

        self.password_confirm_entry = Gtk.Entry()
        self.password_confirm_entry.set_visibility(False)
        form.attach(self.password_confirm_entry, 1, 2, 1, 1)

        box.append(form)

        self.account_error = Gtk.Label(label="")
        self.account_error.add_css_class("error")
        self.account_error.set_wrap(True)
        self.account_error.set_xalign(0.0)
        box.append(self.account_error)

        button_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        back_button = Gtk.Button(label="Back")
        back_button.connect("clicked", lambda *_: self.go_to_network_gate())
        button_row.append(back_button)

        continue_button = Gtk.Button(label="Continue")
        continue_button.connect("clicked", self.on_account_continue)
        button_row.append(continue_button)

        box.append(button_row)
        return box

    def build_disk_page(self):
        box = self.build_page_shell(
            "Step 3: Choose the target disk",
            "The selected disk will be erased completely. The live installer media is filtered out automatically.",
        )

        self.disk_status = Gtk.Label(label="")
        self.disk_status.set_wrap(True)
        self.disk_status.set_xalign(0.0)
        box.append(self.disk_status)

        self.disk_dropdown = Gtk.DropDown()
        box.append(self.disk_dropdown)

        button_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        refresh_button = Gtk.Button(label="Refresh disks")
        refresh_button.connect("clicked", lambda *_: self.refresh_disks())
        button_row.append(refresh_button)

        back_button = Gtk.Button(label="Back")
        back_button.connect("clicked", lambda *_: self.stack.set_visible_child_name("account"))
        button_row.append(back_button)

        continue_button = Gtk.Button(label="Continue")
        continue_button.connect("clicked", self.on_disk_continue)
        button_row.append(continue_button)

        box.append(button_row)
        return box

    def build_confirm_page(self):
        box = self.build_page_shell(
            "Step 4: Confirm destructive install",
            "The installer will create EFI, OS, and DATA partitions on the selected disk.",
        )

        self.confirm_summary = Gtk.Label(label="")
        self.confirm_summary.set_wrap(True)
        self.confirm_summary.set_xalign(0.0)
        box.append(self.confirm_summary)

        self.confirm_error = Gtk.Label(label="")
        self.confirm_error.add_css_class("error")
        self.confirm_error.set_wrap(True)
        self.confirm_error.set_xalign(0.0)
        box.append(self.confirm_error)

        button_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        back_button = Gtk.Button(label="Back")
        back_button.connect("clicked", lambda *_: self.stack.set_visible_child_name("disk"))
        button_row.append(back_button)

        install_button = Gtk.Button(label="Erase disk and install")
        install_button.add_css_class("destructive-action")
        install_button.connect("clicked", self.on_start_install)
        button_row.append(install_button)

        box.append(button_row)
        return box

    def build_install_page(self):
        box = self.build_page_shell(
            "Installing",
            "The installer is partitioning, generating configuration, and running nixos-install. Do not power off the machine.",
        )

        self.install_status = Gtk.Label(label=f"Logs are written to {LOG_FILE}")
        self.install_status.set_wrap(True)
        self.install_status.set_xalign(0.0)
        box.append(self.install_status)

        scroller = Gtk.ScrolledWindow()
        scroller.set_hexpand(True)
        scroller.set_vexpand(True)

        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(False)
        self.log_view.set_monospace(True)
        self.log_view.set_vexpand(True)
        scroller.set_child(self.log_view)

        box.append(scroller)

        button_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        self.retry_button = Gtk.Button(label="Back to disk selection")
        self.retry_button.set_visible(False)
        self.retry_button.connect("clicked", lambda *_: self.stack.set_visible_child_name("disk"))
        button_row.append(self.retry_button)

        self.reboot_button = Gtk.Button(label="Reboot into installed system")
        self.reboot_button.set_visible(False)
        self.reboot_button.connect("clicked", self.on_reboot)
        button_row.append(self.reboot_button)

        box.append(button_row)
        return box

    def go_to_network_gate(self):
        if self.has_working_network():
            self.network_status.set_text("Networking is ready. Continuing to user setup.")
            self.stack.set_visible_child_name("account")
            return

        self.network_status.set_text(
            "No working internet connection is available yet. Open Settings, connect to Wi-Fi or Ethernet, then retry."
        )
        self.stack.set_visible_child_name("network")

    def has_working_network(self):
        nm_result = run_command(["nm-online", "-q", "--timeout=5"])
        if nm_result.returncode != 0:
            return False

        try:
            with urllib.request.urlopen("https://cache.nixos.org/nix-cache-info", timeout=5):
                return True
        except (urllib.error.URLError, TimeoutError):
            return False

    def on_open_network_settings(self, *_args):
        for panel in ("wifi", "network"):
            try:
                subprocess.Popen(["gnome-control-center", panel])
                return
            except FileNotFoundError:
                continue

        self.network_status.set_text("Could not launch GNOME Settings. The live image may be missing gnome-control-center.")

    def on_retry_network(self, *_args):
        self.go_to_network_gate()

    def on_account_continue(self, *_args):
        username = self.username_entry.get_text().strip()
        password = self.password_entry.get_text()
        confirm = self.password_confirm_entry.get_text()

        if not USERNAME_RE.match(username):
            self.account_error.set_text("Username must match ^[a-z_][a-z0-9_-]{0,30}$.")
            return

        if len(password) < 8:
            self.account_error.set_text("Password must be at least 8 characters.")
            return

        if password != confirm:
            self.account_error.set_text("Password confirmation does not match.")
            return

        self.account_error.set_text("")
        self.refresh_disks()
        self.stack.set_visible_child_name("disk")

    def discover_protected_disks(self):
        protected = set()
        for mountpoint in ("/iso", "/run/rootfsbase", "/nix/.ro-store", "/"):
            result = run_command(["findmnt", "-n", "-o", "SOURCE", mountpoint])
            source = result.stdout.strip()
            if not source:
                continue

            resolved = os.path.realpath(source)
            parent = run_command(["lsblk", "-dn", "-o", "PKNAME", resolved]).stdout.strip()
            if parent:
                protected.add(f"/dev/{parent}")

            direct = run_command(["lsblk", "-dn", "-o", "PATH", resolved]).stdout.strip()
            if direct:
                protected.add(direct)

        return protected

    def refresh_disks(self):
        self.disks = []
        protected = self.discover_protected_disks()
        result = run_command(
            [
                "lsblk",
                "--json",
                "-d",
                "-o",
                "NAME,PATH,SIZE,MODEL,SERIAL,TYPE,RM,TRAN",
            ]
        )

        if result.returncode != 0:
            self.disk_status.set_text("Failed to query block devices.")
            self.disk_dropdown.set_model(Gtk.StringList.new([]))
            return

        payload = json.loads(result.stdout)
        for device in payload.get("blockdevices", []):
            if device.get("type") != "disk":
                continue

            if int(device.get("rm") or 0) != 0:
                continue

            path = device.get("path") or f"/dev/{device.get('name')}"
            if path in protected:
                continue

            summary_parts = [path, device.get("size", "")]
            model = (device.get("model") or "").strip()
            serial = (device.get("serial") or "").strip()
            transport = (device.get("tran") or "").strip()

            if model:
                summary_parts.append(model)
            if serial:
                summary_parts.append(serial)
            if transport:
                summary_parts.append(transport)

            self.disks.append(
                {
                    "path": path,
                    "summary": "  ".join(part for part in summary_parts if part),
                }
            )

        if not self.disks:
            self.disk_status.set_text("No eligible installation disks were found.")
            self.disk_dropdown.set_model(Gtk.StringList.new([]))
            return

        self.disk_status.set_text("Select one whole disk. The installer will erase it completely.")
        model = Gtk.StringList.new([item["summary"] for item in self.disks])
        self.disk_dropdown.set_model(model)
        self.disk_dropdown.set_selected(0)

    def on_disk_continue(self, *_args):
        index = self.disk_dropdown.get_selected()
        if not self.disks or index >= len(self.disks):
            self.disk_status.set_text("Choose a disk before continuing.")
            return

        username = self.username_entry.get_text().strip()
        selected = self.disks[index]
        self.confirm_summary.set_text(
            "\n".join(
                [
                    f"User: {username}",
                    f"Disk: {selected['summary']}",
                    "Layout: EFI 1 GiB + OS (remainder except last 128 GiB) + DATA 128 GiB",
                    "Timezone: Asia/Shanghai",
                    "Locale: zh_CN.UTF-8",
                    "Desktop: Niri",
                ]
            )
        )
        self.confirm_error.set_text("")
        self.stack.set_visible_child_name("confirm")

    def on_start_install(self, *_args):
        index = self.disk_dropdown.get_selected()
        if not self.disks or index >= len(self.disks):
            self.confirm_error.set_text("Disk selection is no longer valid.")
            return

        username = self.username_entry.get_text().strip()
        password = self.password_entry.get_text()
        disk = self.disks[index]["path"]

        buffer = self.log_view.get_buffer()
        buffer.set_text("")
        self.retry_button.set_visible(False)
        self.reboot_button.set_visible(False)
        self.install_status.set_text(f"Running installer. Live log: {LOG_FILE}")
        self.stack.set_visible_child_name("install")

        self.install_thread = threading.Thread(
            target=self.run_install,
            args=(username, password, disk),
            daemon=True,
        )
        self.install_thread.start()

    def append_log(self, text):
        buffer = self.log_view.get_buffer()
        end = buffer.get_end_iter()
        buffer.insert(end, text)
        return False

    def finish_install(self, return_code):
        if return_code == 0:
            self.install_status.set_text("Installation finished successfully. You can reboot now.")
            self.reboot_button.set_visible(True)
            return False

        self.install_status.set_text(
            f"Installation failed with exit code {return_code}. Review the log above or {LOG_FILE}, then adjust networking or disk selection and retry."
        )
        self.retry_button.set_visible(True)
        return False

    def run_install(self, username, password, disk):
        command = ["sudo", "-n", EXECUTOR_BIN, username, password, disk]
        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
        except FileNotFoundError:
            GLib.idle_add(self.append_log, "Failed to launch the installer executor.\n")
            GLib.idle_add(self.finish_install, 127)
            return

        if process.stdout is not None:
            for line in process.stdout:
                GLib.idle_add(self.append_log, line)

        process.wait()
        GLib.idle_add(self.finish_install, process.returncode)

    def on_reboot(self, *_args):
        subprocess.Popen(["sudo", "-n", "systemctl", "reboot"])


class InstallerApplication(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="site.addzero.niri-installer")

    def do_activate(self):
        window = self.props.active_window
        if window is None:
            window = InstallerWindow(self)
        window.present()


def main():
    app = InstallerApplication()
    raise SystemExit(app.run([]))


if __name__ == "__main__":
    main()
