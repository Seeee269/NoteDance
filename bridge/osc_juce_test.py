from pythonosc.udp_client import SimpleUDPClient
import tkinter as tk

client = SimpleUDPClient("127.0.0.1", 9001)

# convert slider values
def send(x, y):
    pan = x
    pitch = (y*2)-1

    client.send_message("/accel", [pan, pitch])
    print("/accel", pan, pitch)

# GUI
root = tk.Tk()
root.title("OSC XY Controller")

canvas = tk.Canvas(root, width=300, height=300, bg="black")
canvas.pack()

dot = canvas.create_oval(145, 145, 155, 155, fill="red")

def move(event):
    x = event.x / 300
    y = 1 - (event.y / 300)   # invert Y (natural feel)

    # clamp
    x = max(0, min(1, x))
    y = max(0, min(1, y))

    # move dot
    canvas.coords(dot,
                  event.x - 5, event.y - 5,
                  event.x + 5, event.y + 5)

    send(x, y)

canvas.bind("<B1-Motion>", move)

root.mainloop()
