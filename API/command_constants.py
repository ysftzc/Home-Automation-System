# command_constants.py
# This file is created based on the tables in Project Document Page 16 and 19.

# ==========================================
# BOARD #1: AIR CONDITIONER SYSTEM COMMANDS
# Source: Page 16
# ==========================================

# --- GET Commands (PC -> PIC) ---
# Constant bytes sent to read data from the PIC 
CMD_B1_GET_DESIRED_TEMP_LOW  = 0x01  # 00000001B: Desired Temp Low Byte (Fractional)
CMD_B1_GET_DESIRED_TEMP_HIGH = 0x02  # 00000010B: Desired Temp High Byte (Integral)
CMD_B1_GET_AMBIENT_TEMP_LOW  = 0x03  # 00000011B: Ambient Temp Low Byte (Fractional)
CMD_B1_GET_AMBIENT_TEMP_HIGH = 0x04  # 00000100B: Ambient Temp High Byte (Integral)
CMD_B1_GET_FAN_SPEED         = 0x05  # 00000101B: Fan Speed (rps)

# --- Masks and Helper Functions for SET Commands ---
# Format: 10xxxxxx (Low/Fractional) or 11xxxxxx (High/Integral) 

def create_b1_set_desired_temp_low(fractional_val):
    """
    10t5t4t3t2t1t0B -> Desired Temp Low Byte (Fractional)
    Combines the given 6-bit fractional value with the '10' prefix.
    """
    # We construct the '10xxxxxx' structure using the 0x80 (10000000) mask.
    # Data is limited to 6 bits (0x3F).
    return 0x80 | (int(fractional_val) & 0x3F)

def create_b1_set_desired_temp_high(integral_val):
    """
    11t5t4t3t2t1t0B -> Desired Temp High Byte (Integral)
    Combines the given 6-bit integral value with the '11' prefix.
    """
    # We construct the '11xxxxxx' structure using the 0xC0 (11000000) mask.
    return 0xC0 | (int(integral_val) & 0x3F)


# ==========================================
# BOARD #2: CURTAIN CONTROL SYSTEM COMMANDS
# Source: Page 19
# ==========================================

# --- GET Commands (PC -> PIC) --- 
CMD_B2_GET_CURTAIN_STATUS_LOW    = 0x01  # 00000001B: Desired Curtain Low (Fractional)
CMD_B2_GET_CURTAIN_STATUS_HIGH   = 0x02  # 00000010B: Desired Curtain High (Integral)
CMD_B2_GET_OUTDOOR_TEMP_LOW      = 0x03  # 00000011B: Outdoor Temp Low (Fractional)
CMD_B2_GET_OUTDOOR_TEMP_HIGH     = 0x04  # 00000100B: Outdoor Temp High (Integral)
CMD_B2_GET_OUTDOOR_PRESS_LOW     = 0x05  # 00000101B: Outdoor Pressure Low (Fractional)
CMD_B2_GET_OUTDOOR_PRESS_HIGH    = 0x06  # 00000110B: Outdoor Pressure High (Integral)
CMD_B2_GET_LIGHT_INTENSITY_LOW   = 0x07  # 00000111B: Light Intensity Low (Fractional)
CMD_B2_GET_LIGHT_INTENSITY_HIGH  = 0x08  # 00001000B: Light Intensity High (Integral)

# --- Helper Functions for SET Commands --- 

def create_b2_set_curtain_status_low(fractional_val):
    """
    10C5C4C3C2C1C0B -> Set Desired Curtain Low Byte (Fractional)
    Combines the given 6-bit fractional value with the '10' prefix.
    """
    return 0x80 | (int(fractional_val) & 0x3F)

def create_b2_set_curtain_status_high(integral_val):
    """
    11C5C4C3C2C1C0B -> Set Desired Curtain High Byte (Integral)
    Combines the given 6-bit integral value with the '11' prefix.
    """
    return 0xC0 | (int(integral_val) & 0x3F)