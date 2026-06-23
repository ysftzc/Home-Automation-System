"""
Project: Home Automation System Term Project
File: tests_api.py
Description: This script tests the member functions of the API classes as required by [R2.3-2].
Course: Introduction to Microcomputers (ESOGU)
"""

__author__ = "Sevilay Çelik"
__copyright__ = "Copyright 2025, ESOGU Student Project"
__version__ = "1.0.0"
__maintainer__ = "Sevilay Çelik"
__email__ = "152120221045@ogrenci.ogu.edu.tr"
__status__ = "Development"


import time
import serial
from air_conditioner_connection import AirConditionerSystemConnection
from curtain_control_connection import CurtainControlSystemConnection

def test_air_conditioner(port_number):
    """
    Test scenario for Board #1 (Air Conditioner System).
    """
    print(f"\n--- TEST: Air Conditioner System (Port: COM{port_number}) ---")
    
    # 1. Object Creation Test
    ac = AirConditionerSystemConnection()
    print("[PASS] Object created.")

    # 2. Port Configuration Test
    ac.setComPort(port_number)
    ac.setBaudRate(9600)
    print(f"[PASS] Port configured: {ac.getPort()} @ {ac.getBaudRate()}")

    # 3. Connection Open Test
    if not ac.open():
        print("[FAIL] Connection failed! Please ensure the simulator or virtual port is open.")
        return

    print("[PASS] Connection opened successfully.")

    try:
        # 4. Data Sending Test (setDesiredTemp)
        test_temp = 24.5
        if ac.setDesiredTemp(test_temp):
            print(f"[PASS] setDesiredTemp({test_temp}) command sent.")
        else:
            print("[FAIL] setDesiredTemp failed.")

        # 5. Data Reading Test (update & getters)
        # Note: If there is no real simulation on the other end, these values might be 0 or timeout.
        print("Reading data (Waiting for response from Simulation)...")
        ac.update()
        
        print(f"  -> Ambient Temp: {ac.getAmbientTemp()}")
        print(f"  -> Desired Temp: {ac.getDesiredTemp()}")
        print(f"  -> Fan Speed:    {ac.getFanSpeed()}")
        print("[PASS] Reading functions executed without error.")

    except Exception as e:
        print(f"[FAIL] Error occurred during test: {e}")
    finally:
        # 6. Connection Close Test
        ac.close()
        print("[PASS] Connection closed.")

def test_curtain_control(port_number):
    """
    Test scenario for Board #2 (Curtain Control System).
    """
    print(f"\n--- TEST: Curtain Control System (Port: COM{port_number}) ---")
    
    # 1. Object Creation Test
    cc = CurtainControlSystemConnection()
    print("[PASS] Object created.")

    # 2. Port Configuration Test
    cc.setComPort(port_number)
    cc.setBaudRate(9600)
    print(f"[PASS] Port configured: {cc.getPort()} @ {cc.getBaudRate()}")

    # 3. Connection Open Test
    if not cc.open():
        print("[FAIL] Connection failed! Check virtual ports.")
        return

    print("[PASS] Connection opened successfully.")

    try:
        # 4. Data Sending Test (setCurtainStatus)
        test_status = 50.0 # 50% open
        if cc.setCurtainStatus(test_status):
            print(f"[PASS] setCurtainStatus({test_status}) command sent.")
        else:
            print("[FAIL] setCurtainStatus failed.")

        # 5. Data Reading Test (update & getters)
        print("Reading data (Waiting for response from Simulation)...")
        cc.update()
        
        print(f"  -> Outdoor Temp:  {cc.getOutdoorTemp()}")
        print(f"  -> Outdoor Press: {cc.getOutdoorPress()}")
        # Attribute check (Safety check if attribute exists)
        curtain_val = getattr(cc, '_curtain_status', 0.0)
        print(f"  -> Curtain Status: {curtain_val}")
        print(f"  -> Light Intensity: {cc.getLightIntensity()}")
        print("[PASS] Reading functions executed without error.")

    except Exception as e:
        print(f"[FAIL] Error occurred during test: {e}")
    finally:
        # 6. Connection Close Test
        cc.close()
        print("[PASS] Connection closed.")

if __name__ == "__main__":
    print("==========================================")
    print("   HOME AUTOMATION API TEST SUITE")
    print("==========================================")
    print("NOTE: For this test to pass successfully, virtual ports (com0com)")
    print("or PICSimLab simulation must be running.\n")

    try:
        p1 = int(input("Test Board #1 Port No (e.g., 1): "))
        test_air_conditioner(p1)
        
        p2 = int(input("Test Board #2 Port No (e.g., 3): "))
        test_curtain_control(p2)
        
    except ValueError:
        print("ERROR: Please enter numbers only.")
    
    print("\nTest completed.")