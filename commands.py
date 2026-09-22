# Ajusta esta ruta si tu carpeta de Reaper no es exactamente esta.
# Puedes confirmarla en Reaper con: Options -> Show REAPER resource path
COMMAND_FILE = r"C:\Users\sergi\AppData\Roaming\REAPER\Scripts\livecoding_cmd.txt"


def send_command(text):
    with open(COMMAND_FILE, "w") as f:
        f.write(text)
    print("Enviado:", text)


if __name__ == "__main__":
    # Ejemplo de uso: cambia la nota que suena en la pista 0
    send_command("eliminar_nota pista=0 nota=60 inicio=0 duracion=2")