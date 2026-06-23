"""
Project: Home Automation System Term Project
File: air_conditioner_connection.py
Description: This file is responsible for connecting to the board #1 via UART port.
"""

__author__ = "Sevilay Çelik"
__copyright__ = "Copyright 2025, ESOGU Student Project"
__version__ = "1.0.0"

from home_automation_connection import HomeAutomationSystemConnection
import command_constants as cmd
import time

class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    """
    Manages Board #1 (Air Conditioner System) connection and data. 
    """

    def __init__(self):
        super().__init__()
        self._desired_temperature = 0.0
        self._ambient_temperature = 0.0
        self._fan_speed = 0

    def update(self):
        if not self.serial_connection or not self.serial_connection.is_open:
            return

        try:
            # 1. Ambient Temp
            self._ambient_temperature = self._read_sensor_value(
                cmd.CMD_B1_GET_AMBIENT_TEMP_HIGH,
                cmd.CMD_B1_GET_AMBIENT_TEMP_LOW
            )
            # 2. Desired Temp
            self._desired_temperature = self._read_sensor_value(
                cmd.CMD_B1_GET_DESIRED_TEMP_HIGH,
                cmd.CMD_B1_GET_DESIRED_TEMP_LOW
            )
            # 3. Fan Speed 
            self.serial_connection.write(bytes([cmd.CMD_B1_GET_FAN_SPEED]))
            data = self.serial_connection.read(1)
            if len(data) == 1:
                self._fan_speed = int.from_bytes(data, 'big')

        except Exception as e:
            print(f"Board #1 Update Error: {e}")

    def _read_sensor_value(self, cmd_high, cmd_low) -> float:
        """
        DÜZELTİLMİŞ OKUMA: Bekleme (sleep) yok, Blocking Read var.
        """
        value = 0.0
        try:
            # High Byte
            self.serial_connection.write(bytes([cmd_high]))
            high_data = self.serial_connection.read(1)

            if len(high_data) == 1:
                high = int.from_bytes(high_data, 'big')
                
                # Low Byte
                self.serial_connection.write(bytes([cmd_low]))
                low_data = self.serial_connection.read(1)
                
                if len(low_data) == 1:
                    low = int.from_bytes(low_data, 'big')
                    value = float(high) + (float(low) / 10.0)
        except:
            pass
        return value

    def setDesiredTemp(self, temp: float) -> bool:
        if not self.serial_connection or not self.serial_connection.is_open:
            return False

        try:
            integral_part = int(temp)
            fractional_part = int(round((temp - integral_part) * 10))

            cmd_high = cmd.create_b1_set_desired_temp_high(integral_part)
            self.serial_connection.write(bytes([cmd_high]))
            time.sleep(0.05)

            cmd_low = cmd.create_b1_set_desired_temp_low(fractional_part)
            self.serial_connection.write(bytes([cmd_low]))
            
            self._desired_temperature = temp
            return True
        except Exception as e:
            print(f"Set Temp Error: {e}")
            return False

    def getAmbientTemp(self) -> float: return self._ambient_temperature
    def getDesiredTemp(self) -> float: return self._desired_temperature

    def getFanSpeed(self) -> int: return self._fan_speed
