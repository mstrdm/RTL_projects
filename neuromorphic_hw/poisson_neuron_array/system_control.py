import numpy as np
import serial
import time
import pyqtgraph as pg
from pyqtgraph.Qt import QtCore, QtGui
import pyqtgraph.multiprocess as mp
import threading
from PIL import Image

class EventPlotter(object):
	def __init__(self, ser):
		self.app = pg.mkQApp()
		self.proc = mp.QtProcess()
		self.rpg = self.proc._import('pyqtgraph')
				
		self.plotwin = self.rpg.GraphicsWindow(title="Monitor")
		# self.plotwin = pg.GraphicsWindow(title="Monitor")
		self.plotwin.resize(1000,600)
		self.plotwin.setWindowTitle('Activity Monitor')
		self.p1 = self.plotwin.addPlot(title="Neuron spikes vs. time")
		self.p1.setLabel('left', 'Neuron Id')
		self.p1.setLabel('bottom', 'Time [s]')
		self.p1.showGrid(x=True, y=True, alpha=0.5)
		self.spikes_curve = self.p1.plot(pen=None, symbol="o", symbolPen=None, symbolBrush='w', symbolSize=3)   

		# self.app.exit(self.app.exec_()) # not sure if this is necessary
		
		self.on_screen = 400 # Number of events on the screen
		self.all_time_stamps = np.zeros(self.on_screen)
		self.all_addresses = np.zeros(self.on_screen, dtype=int)
		
		self.ser = ser

		self.old_stamp = 0

	def decode_events(self, byte_data):
		time_stamps = []
		addresses = []
		event_nr = int(len(byte_data)/3)
		
		if event_nr > 0:
			for e in range(event_nr):
				event = byte_data[e*3:e*3+3]
				addresses.append(event[2])
				new_stamp = int.from_bytes(event[0:2], byteorder='big')

				time_stamps.append(new_stamp)
				
		return time_stamps, addresses

	def ReadEvents(self):
		try:
			event_data = self.ser.read(300)
			time_stamps, addresses = self.decode_events(event_data)
			dn = len(time_stamps)
			if dn > 0:
				self.all_time_stamps = np.roll(self.all_time_stamps, -dn)
				self.all_addresses = np.roll(self.all_addresses, -dn)
				self.all_time_stamps[-dn:] = np.array(time_stamps)
				self.all_addresses[-dn:] = np.array(addresses)
				
				self.spikes_curve.setData(x=self.all_time_stamps, y=self.all_addresses, _callSync='off')
		except:
			None

class ImageConverter(object):
	def __init__(self, ser):
		self.ser = ser
		self.size = (16,16)
		self.max_act = 120	# in increments of 0.25Hz

	def load_img(self, path):
		img = Image.open(path).convert('L') # loading image and converting to greyscale
		img = img.resize(self.size, Image.ANTIALIAS) # downscaling
		img = img.transpose(Image.TRANSPOSE)
		image = np.array(img) # converting to numpy array
		image = 120*(1 - abs(image/np.max(image))) # normalization

		for i in range(self.size[0]):
			for ii in range(self.size[1]):
				image[i,ii] = int(image[i,ii])

		return image

	def SendIMG(self, path):
		n_addr = 0
		image = self.load_img(path)
		for i in range(self.size[0]):
			for ii in range(self.size[1]):
				n_addr = i*self.size[0] + ii
				if (n_addr == 255):
					None
				else:
					self.ser.write(bytes([int(n_addr)]))
					self.ser.write(bytes([int(image[i,ii])]))

# Serial Port Initialization
ser = serial.Serial()
ser.baudrate = 115200
ser.port = 'COM5'
ser.timeout = 0.1
ser.open()

# Flags
script_on = True
spikes_on = False

# Objects
EventPlotter = EventPlotter(ser=ser)
ImageConverter = ImageConverter(ser=ser)

def cmd_in():
	global script_on, spikes_on, ImageConverter, EventPlotter
	while True:
		cmd_raw = input("cmd?:").split()
		cmd = cmd_raw[0]
		if (len(cmd_raw) > 1):
			cmd_param = cmd_raw[1]
		else: cmd_param = 0

		if (cmd == "stop"):
			script_on = False
			break

		elif (cmd == "show"):
			try:
				EventPlotter.on_screen = int(cmd_param)
				EventPlotter.all_time_stamps = np.zeros(EventPlotter.on_screen)
				EventPlotter.all_addresses = np.zeros(EventPlotter.on_screen, dtype=int)
			except:
				print("Invalid number after show command.\n")

		elif (cmd == "clear"):
			EventPlotter.all_time_stamps = np.zeros(EventPlotter.on_screen)
			EventPlotter.all_addresses = np.zeros(EventPlotter.on_screen, dtype = int)

		elif (cmd == "pause"):
			spikes_on = False
			time.sleep(0.1)
			ser.write(bytes.fromhex('FF'))
			

		elif (cmd == "go"):
			if spikes_on == False:
				ser.write(bytes.fromhex('01'))
				spikes_on = True
			ImageConverter.SendIMG("img.bmp")
			

		else:
			print("Not a legal command.\n")

# def run_img():
# 	global script_on, spikes_on
# 	while script_on == True:
# 		while spikes_on == True:
# 			ImageConverter.SendIMG("img.bmp")
# 			time.sleep(1)
# 		time.sleep(0.5)

def run_plot():
	global script_on, EventPlotter, spikes_on
	while script_on == True:
		time.sleep(100e-3)
		EventPlotter.ReadEvents()
	EventPlotter.proc.close()

thread_plot = threading.Thread(target=run_plot)
thread_plot.daemon = False
thread_plot.start()

# thread_img = threading.Thread(target=run_img)
# thread_img.daemon = False
# thread_img.start()

cmd_in()