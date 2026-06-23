"""
Project: Home Automation System Term Project
File: curtain_control_connection.py
Description: This file is responsible for connecting to the board #2 via UART port.
"""

__author__ = "Sevilay Çelik"
__copyright__ = "Copyright 2025, ESOGU Student Project"
__version__ = "1.0.0"

from home_automation_connection import HomeAutomationSystemConnection
import command_constants as cmd
import time

class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    """
    Board #2 Curtain Control System Connection Class
    """

    def __init__(self):
        super().__init__()
        self._curtain_status = 0.0
        self._outdoor_temperature = 0.0
        self._outdoor_pressure = 0.0
        self._light_intensity = 0.0

    def update(self):
        """
        Sends 'GET' commands to the board for all data and updates member variables.
        """
        if not self.serial_connection or not self.serial_connection.is_open:
            return

        try:
            # 1. Curtain Status
            self._curtain_status = self._read_sensor_value(
                cmd.CMD_B2_GET_CURTAIN_STATUS_HIGH,
                cmd.CMD_B2_GET_CURTAIN_STATUS_LOW
            )
            # 2. Outdoor Temp
            self._outdoor_temperature = self._read_sensor_value(
                cmd.CMD_B2_GET_OUTDOOR_TEMP_HIGH,
                cmd.CMD_B2_GET_OUTDOOR_TEMP_LOW
            )
            # 3. Outdoor Pressure
            self._outdoor_pressure = self._read_sensor_value(
                cmd.CMD_B2_GET_OUTDOOR_PRESS_HIGH,
                cmd.CMD_B2_GET_OUTDOOR_PRESS_LOW
            )
            # 4. Light Intensity
            self._light_intensity = self._read_sensor_value(
                cmd.CMD_B2_GET_LIGHT_INTENSITY_HIGH,
                cmd.CMD_B2_GET_LIGHT_INTENSITY_LOW
            )

        except Exception as e:
            print(f"Board #2 Update Error: {e}")

    def _read_sensor_value(self, cmd_high, cmd_low) -> float:
        
        value = 0.0
        try:
            # High Byte
            self.serial_connection.write(bytes([cmd_high]))
            high_data = self.serial_connection.read(1) # Cevap gelene kadar bekle

            if len(high_data) == 1:
                high = int.from_bytes(high_data, 'big')
                
                # Low Byte
                self.serial_connection.write(bytes([cmd_low]))
                low_data = self.serial_connection.read(1) # Cevap gelene kadar bekle
                
                if len(low_data) == 1:
                    low = int.from_bytes(low_data, 'big')
                    value = float(high) + (float(low) / 10.0)
            
        except Exception as e:
            print(f"Okuma Hatası: {e}")
        
        return value

    def setCurtainStatus(self, status: float) -> bool:
        if not self.serial_connection or not self.serial_connection.is_open:
            return False

        try:
            integral_part = int(status)
            fractional_part = int(round((status - integral_part) * 10))

            cmd_high = cmd.create_b2_set_curtain_status_high(integral_part)
            self.serial_connection.write(bytes([cmd_high]))
            time.sleep(0.05) # Yazma işleminde kısa bekleme iyidir

            cmd_low = cmd.create_b2_set_curtain_status_low(fractional_part)
            self.serial_connection.write(bytes([cmd_low]))
            
            self._curtain_status = status
            return True
        except Exception as e:
            print(f"Set Curtain Error: {e}")
            return False

    # Getters
    def getOutdoorTemp(self) -> float: return self._outdoor_temperature
    def getOutdoorPress(self) -> float: return self._outdoor_pressure

    def getLightIntensity(self) -> float: return self._light_intensity
