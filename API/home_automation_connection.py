"""
Project: Home Automation System Term Project
File: home_automation_connection.py
Description: This file contains the class which is responsible for connecting to the board via UART port.
Course: Introduction to Microcomputers (ESOGU)
"""

__author__ = "Sevilay Çelik"
__copyright__ = "Copyright 2025, ESOGU Student Project"
__version__ = "1.0.0"
__maintainer__ = "Sevilay Çelik"
__email__ = "152120221045@ogrenci.ogu.edu.tr"
__status__ = "Development"
import serial
import time

class HomeAutomationSystemConnection:
    """
    This class is responsible for connecting to the board via UART port.
    """

    def __init__(self):
        # The variables which is defined as private in UML are initialized here.
        self._com_port_str = "" 
        self._baud_rate = 9600
        self.serial_connection = None # pyserial object

    def setComPort(self, port: int):
        """
         Set the communication port number.
        Because UML requires an 'int', the parameter is taken as an int, 
        but the pyserial library expects a string (e.g., "COM1").
        This method converts the int value to Windows format ("COMx").
        """
        self._com_port_str = f"COM{port}"
        print(f"Port is set: {self._com_port_str}")
        
    def getPort(self):
        return self._com_port_str
        
    def setBaudRate(self, rate: int):
        """
         Set the communication baudrate.
        """
        self._baud_rate = rate
        print(f"Baudrate is set: {self._baud_rate}")
        
    def getBaudRate(self):
        return self._baud_rate
        
    def open(self) -> bool:
        """
         Initiate a connection to the Board via UART port.
         Returns if connection is successful or not. If successful, True, otherwise False.
        """
        try:
            # If conneciton is already open, close it
            if self.serial_connection and self.serial_connection.is_open:
                self.serial_connection.close()

        
            self.serial_connection = serial.Serial(
                port=self._com_port_str,
                baudrate=self._baud_rate,
                timeout=5,        # KRİTİK AYAR: 5 Saniye Bekleme
                write_timeout=5   # Yazma için de 5 saniye
            )
            
            if self.serial_connection.is_open:
                print(f" Connection is successful: {self._com_port_str} @ {self._baud_rate}")
                return True
            
        except serial.SerialException as e:
            print(f"Connection error: {e}")
            return False
        except ValueError:
            print("Error: Invalid port number.")
            return False
            
        return False

    def close(self) -> bool:
        """
         Closes the connection to the board.
        """
        try:
            if self.serial_connection and self.serial_connection.is_open:
                self.serial_connection.close()
                print("Connection is closed.")
                return True
            return True # Zaten kapalıysa da başarılı sayıyoruz
        except Exception as e:
            print(f"Error during closing connection: {e}")
            return False

    def update(self):
        """
         Gets all data and updates the member data.
        This is a base class and it must be empty. Child classes must have their own implementation.
        (Override this method in child classes)
        """

        pass
