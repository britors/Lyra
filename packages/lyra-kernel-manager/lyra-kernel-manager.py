#!/usr/bin/env python3
"""Lyra OS — Kernel Manager (§7).

A deliberately small graphical utility to install/remove kernels on Lyra OS.
Philosophy (spec §1): hide complexity behind good defaults.

Key rule (spec §6/§7): a kernel is NEVER installed without its matching
``*-headers`` package, otherwise DKMS modules (NVIDIA on linux-zen) stop
rebuilding on kernel updates. The app enforces this by always operating on the
pair ``<kernel> <kernel>-headers`` together.
"""
from __future__ import annotations

import os
import subprocess
import sys

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QApplication,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

# Curated kernel set for Lyra OS (spec §7). linux-zen is the default; linux is
# mainline; linux-lts is the safety net for older/quirky hardware.
KERNELS = [
    ("linux-zen", "Lyra (linux-zen)", "Padrão — responsivo para desktop e jogos."),
    ("linux", "Padrão (linux)", "Kernel mainline do Arch."),
    ("linux-lts", "Suporte longo (linux-lts)", "Estável; ideal para hardware antigo."),
    ("linux-hardened", "Reforçado (linux-hardened)", "Foco em segurança."),
]


def pacman_q(pkg: str) -> bool:
    """Return True if *pkg* is installed."""
    return subprocess.run(
        ["pacman", "-Q", pkg],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def running_kernel_pkg() -> str | None:
    """Best-effort map of the running kernel to its package name."""
    release = os.uname().release  # e.g. "6.9.3-zen1-1-zen"
    for pkg, _, _ in KERNELS:
        suffix = pkg.split("linux", 1)[1]  # "", "-zen", "-lts", "-hardened"
        tag = suffix.lstrip("-") or "arch"  # mainline shows as "-archN"
        if tag in release:
            return pkg
    return None


def run_privileged(action: str, kernel: str) -> tuple[bool, str]:
    """Run pacman via pkexec on the kernel + its headers together."""
    headers = f"{kernel}-headers"
    if action == "install":
        cmd = ["pacman", "-S", "--needed", "--noconfirm", kernel, headers]
    else:  # remove
        cmd = ["pacman", "-Rns", "--noconfirm", kernel, headers]
    proc = subprocess.run(
        ["pkexec", *cmd], capture_output=True, text=True
    )
    ok = proc.returncode == 0
    return ok, (proc.stderr or proc.stdout)


class KernelRow(QFrame):
    def __init__(self, pkg: str, title: str, subtitle: str, parent_window):
        super().__init__()
        self.pkg = pkg
        self.window_ref = parent_window
        self.setObjectName("kernelRow")
        self.setFrameShape(QFrame.StyledPanel)

        layout = QHBoxLayout(self)
        text = QVBoxLayout()
        name = QLabel(f"<b>{title}</b>")
        desc = QLabel(subtitle)
        desc.setStyleSheet("color: palette(mid);")
        text.addWidget(name)
        text.addWidget(desc)
        layout.addLayout(text)
        layout.addStretch()

        self.status = QLabel()
        layout.addWidget(self.status)

        self.action_btn = QPushButton()
        self.action_btn.clicked.connect(self.toggle)
        layout.addWidget(self.action_btn)

        self.refresh()

    def refresh(self):
        installed = pacman_q(self.pkg)
        is_running = self.pkg == running_kernel_pkg()
        if installed:
            label = "Instalado" + (" (em uso)" if is_running else "")
            self.status.setText(f"<span style='color:#6ea6ff'>{label}</span>")
            self.action_btn.setText("Remover")
            # Never let the user remove the kernel they are currently running.
            self.action_btn.setEnabled(not is_running)
        else:
            self.status.setText("<span style='color:palette(mid)'>Não instalado</span>")
            self.action_btn.setText("Instalar")
            self.action_btn.setEnabled(True)

    def toggle(self):
        installed = pacman_q(self.pkg)
        action = "remove" if installed else "install"
        verb = "Remover" if installed else "Instalar"

        if action == "remove":
            installed_kernels = [k for k, _, _ in KERNELS if pacman_q(k)]
            if len(installed_kernels) <= 1:
                QMessageBox.warning(
                    self, "Lyra", "Este é o único kernel instalado. "
                    "Instale outro antes de removê-lo."
                )
                return

        self.action_btn.setEnabled(False)
        self.action_btn.setText("Aguarde…")
        QApplication.processEvents()
        ok, output = run_privileged(action, self.pkg)
        if not ok:
            QMessageBox.critical(self, "Lyra", f"Falha ao {verb.lower()}:\n\n{output}")
        self.window_ref.refresh_all()


class KernelManager(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Lyra — Gerenciador de Kernel")
        self.resize(560, 420)
        layout = QVBoxLayout(self)

        header = QLabel("<h2>Gerenciador de Kernel</h2>")
        sub = QLabel(
            "Os cabeçalhos (<i>headers</i>) são sempre instalados junto — "
            "necessário para drivers NVIDIA recompilarem a cada atualização."
        )
        sub.setWordWrap(True)
        sub.setStyleSheet("color: palette(mid);")
        layout.addWidget(header)
        layout.addWidget(sub)

        self.rows = []
        for pkg, title, subtitle in KERNELS:
            row = KernelRow(pkg, title, subtitle, self)
            self.rows.append(row)
            layout.addWidget(row)
        layout.addStretch()

    def refresh_all(self):
        for row in self.rows:
            row.refresh()


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("Lyra Kernel Manager")
    win = KernelManager()
    win.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
