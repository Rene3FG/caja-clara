"""Carga el seed de verificación. No corre al arrancar la API."""
from datetime import datetime

import db


def main():
    db.iniciar()
    db.sembrar_verificacion(datetime.now().strftime("%Y-%m-%d"))


if __name__ == "__main__":
    main()
