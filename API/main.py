"""
Project: Home Automation System Term Project
File: main_gui_threaded.py
Description: GUI with Background Thread to prevent freezing.
Author: Sevilay Çelik
"""

import ttkbootstrap as ttk
from ttkbootstrap.constants import *
from ttkbootstrap.dialogs import Messagebox, Querybox
import sys
import threading
import time

# Import API classes
try:
    from air_conditioner_connection import AirConditionerSystemConnection
    from curtain_control_connection import CurtainControlSystemConnection
except ImportError:
    pass # Hata yönetimi

class HomeAutomationMenuApp:
    def __init__(self, root):
        self.root = root
        self.root.title("ESOGU Smart Home System")
        self.root.geometry("900x700")
        
        # --- API Objects ---
        self.ac_system = AirConditionerSystemConnection()
        self.cc_system = CurtainControlSystemConnection()
        
        self.ac_connected = False
        self.cc_connected = False
        
        # Thread Kontrol Bayrağı (Program kapanınca thread dursun diye)
        self.running = True

        # --- GUI  ---
        self.container = ttk.Frame(self.root)
        self.container.pack(fill=BOTH, expand=True)

        self.frames = {}
        for F in (MainMenuPage, AirConditionerPage, CurtainControlPage):
            page_name = F.__name__
            frame = F(parent=self.container, controller=self)
            self.frames[page_name] = frame
            frame.grid(row=0, column=0, sticky="nsew")

        self.show_frame("MainMenuPage")

       
        # thread
        self.worker_thread = threading.Thread(target=self.background_data_loop, daemon=True)
        self.worker_thread.start()

        # --- updater
        # Bu fonksiyon sadece hazır olan veriyi ekrana yazar, bekleme yapmaz.
        self.root.after(1000, self.update_gui_loop)

       
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def show_frame(self, page_name):
        frame = self.frames[page_name]
        frame.tkraise()

    def connect_ac(self, port_num):
        try:
            self.ac_system.setComPort(int(port_num))
            self.ac_system.setBaudRate(9600)
            if self.ac_system.open():
                self.ac_connected = True
                return True
        except: return False

    def connect_cc(self, port_num):
        try:
            self.cc_system.setComPort(int(port_num))
            self.cc_system.setBaudRate(9600)
            if self.cc_system.open():
                self.cc_connected = True
                return True
        except: return False

    
    def background_data_loop(self):
        """
        Bu fonksiyon ana programdan ayrı bir dünyada çalışır.
        PIC 10 saniye cevap vermese bile sadece burası bekler, Arayüz donmaz!
        """
        while self.running:
            # 1. Klima Verisini Çek (Bekleme yapabilir)
            if self.ac_connected:
                try: self.ac_system.update()
                except: pass

            # 2. Perde Verisini Çek (Bekleme yapabilir)
            if self.cc_connected:
                try: self.cc_system.update()
                except: pass
            
            # İşlemciyi yormamak için kısa mola
            time.sleep(0.5)

    # --- ARAYÜZ GÜNCELLEYİCİ (Patron) ---
    def update_gui_loop(self):
        """
        Bu fonksiyon saniyede bir kez çalışır ve 
        arkadaki işçinin getirdiği SON veriyi ekrana yazar. Asla beklemez.
        """
        # AC Sayfası Güncelle
        if self.ac_connected:
            try:
                page = self.frames["AirConditionerPage"]
                page.update_meters(
                    self.ac_system.getAmbientTemp(),
                    self.ac_system.getDesiredTemp(),
                    self.ac_system.getFanSpeed()
                )
            except: pass

        # Perde Sayfası Güncelle
        if self.cc_connected:
            try:
                page = self.frames["CurtainControlPage"]
                # curtain_status değişkenine erişim
                val = getattr(self.cc_system, '_curtain_status', 0.0)
                page.update_meters(
                    self.cc_system.getOutdoorTemp(),
                    self.cc_system.getOutdoorPress(),
                    self.cc_system.getLightIntensity(),
                    val
                )
            except: pass

        # Kendini tekrar çağır
        if self.running:
            self.root.after(1000, self.update_gui_loop)

    def on_close(self):
        self.running = False
        if self.ac_connected: self.ac_system.close()
        if self.cc_connected: self.cc_system.close()
        self.root.destroy()
        sys.exit()


# --- SAYFA TASARIMLARI (AYNI KALDI) ---
class MainMenuPage(ttk.Frame):
    def __init__(self, parent, controller):
        ttk.Frame.__init__(self, parent)
        self.controller = controller
        
        main_frame = ttk.Frame(self)
        main_frame.place(relx=0.5, rely=0.5, anchor=CENTER)

        lbl_title = ttk.Label(main_frame, text=" 🏠 ESOGÜ SMART HOME ", font=("Roboto", 28, "bold"), bootstyle="inverse-primary")
        lbl_title.pack(pady=(0, 40), ipadx=10, ipady=10)

        btn1 = ttk.Button(main_frame, text=" ❄️  Air Conditioner System", width=35, bootstyle="info-outline", command=self.on_ac_click)
        btn1.pack(pady=10, ipady=15)

        btn2 = ttk.Button(main_frame, text=" 🌤️  Curtain Control System", width=35, bootstyle="warning-outline", command=self.on_cc_click)
        btn2.pack(pady=10, ipady=15)

        ttk.Button(main_frame, text="Exit Application", width=20, bootstyle="danger", command=self.exit_app).pack(pady=20)
        
    def on_ac_click(self):
        if self.controller.ac_connected:
            self.controller.show_frame("AirConditionerPage")
        else:
            port = Querybox.get_integer(parent=self, title="Connect AC", prompt="Port Number (e.g. 10):", minvalue=1, maxvalue=256)
            if port and self.controller.connect_ac(port):
                Messagebox.show_info("Connected!", "Success")
                self.controller.show_frame("AirConditionerPage")
            elif port: Messagebox.show_error("Failed!", "Error")

    def on_cc_click(self):
        if self.controller.cc_connected:
            self.controller.show_frame("CurtainControlPage")
        else:
            port = Querybox.get_integer(parent=self, title="Connect Curtain", prompt="Port Number (e.g. 11):", minvalue=1, maxvalue=256)
            if port and self.controller.connect_cc(port):
                Messagebox.show_info("Connected!", "Success")
                self.controller.show_frame("CurtainControlPage")
            elif port: Messagebox.show_error("Failed!", "Error")

    def exit_app(self):
        self.controller.on_close()

class AirConditionerPage(ttk.Frame):
    def __init__(self, parent, controller):
        ttk.Frame.__init__(self, parent)
        self.controller = controller
        
        ttk.Label(self, text=" ❄️ CLIMATE CONTROL", font=("Roboto", 22, "bold"), bootstyle="inverse-info").pack(pady=15, fill=X)
        
        gauges_frame = ttk.Frame(self)
        gauges_frame.pack(pady=20)

        self.meter_amb = ttk.Meter(gauges_frame, metersize=180, amountused=0, metertype="semi", subtext="Ambient °C", interactive=False, bootstyle="danger")
        self.meter_amb.pack(side=LEFT, padx=20)

        self.lbl_des = ttk.Label(gauges_frame, text="-- °C", font=("Roboto", 30, "bold"), bootstyle="warning")
        self.lbl_des.pack(side=LEFT, padx=20)

        self.meter_fan = ttk.Meter(gauges_frame, metersize=180, amounttotal=100, amountused=0, metertype="full", subtext="Fan Speed", interactive=False, bootstyle="info")
        self.meter_fan.pack(side=LEFT, padx=20)

        ctrl_frame = ttk.Labelframe(self, text="Set Temperature", padding=10)
        ctrl_frame.pack(pady=20)
        
        self.ent_temp = ttk.Entry(ctrl_frame, width=10)
        self.ent_temp.pack(side=LEFT, padx=5)
        ttk.Button(ctrl_frame, text="SET", command=self.send_temp, bootstyle="success").pack(side=LEFT, padx=5)
        
        ttk.Button(self, text="⬅ Back", command=lambda: controller.show_frame("MainMenuPage")).pack(pady=20)

    def update_meters(self, amb, des, fan):
        self.meter_amb.configure(amountused=int(amb))
        self.lbl_des.config(text=f"{des:.1f} °C")
        self.meter_fan.configure(amountused=int(fan))

    def send_temp(self):
        try:
            val = float(self.ent_temp.get())
            if self.controller.ac_system.setDesiredTemp(val):
                Messagebox.show_info("Sent!", "Success")
        except: pass

class CurtainControlPage(ttk.Frame):
    def __init__(self, parent, controller):
        ttk.Frame.__init__(self, parent)
        self.controller = controller
        
        ttk.Label(self, text=" 🌤️ CURTAIN AUTOMATION", font=("Roboto", 22, "bold"), bootstyle="inverse-warning").pack(pady=15, fill=X)

        main_grid = ttk.Frame(self)
        main_grid.pack(pady=20)
        
        
        left_col = ttk.Labelframe(main_grid, text="Sensors", padding=10)
        left_col.pack(side=LEFT, padx=20)
        # sensors
        self.lbl_temp = ttk.Label(left_col, text="Temp: --", font=("Roboto", 14))
        self.lbl_temp.pack(pady=5)
        self.lbl_press = ttk.Label(left_col, text="Press: --", font=("Roboto", 14))
        self.lbl_press.pack(pady=5)
        self.lbl_light = ttk.Label(left_col, text="Light: --", font=("Roboto", 14))
        self.lbl_light.pack(pady=5)

        # Curtain
        right_col = ttk.Labelframe(main_grid, text="Curtain Status", padding=10)
        right_col.pack(side=LEFT, padx=20)
        
        self.meter_curtain = ttk.Meter(right_col, metersize=200, amounttotal=100, amountused=0, metertype="full", subtext="Open %", interactive=False, bootstyle="success")
        self.meter_curtain.pack()

        #Control
        ctrl = ttk.Frame(self)
        ctrl.pack(pady=10)
        self.ent_curt = ttk.Entry(ctrl, width=10)
        self.ent_curt.pack(side=LEFT, padx=5)
        ttk.Button(ctrl, text="MOVE", command=self.send_curtain, bootstyle="success").pack(side=LEFT)

        ttk.Button(self, text="⬅ Back", command=lambda: controller.show_frame("MainMenuPage")).pack(pady=20)

    def update_meters(self, temp, press, light, status):
        self.lbl_temp.config(text=f"Temp: {temp:.1f} °C")
        self.lbl_press.config(text=f"Press: {press:.1f} hPa")
        self.lbl_light.config(text=f"Light: {light:.1f} Lux")
        self.meter_curtain.configure(amountused=int(status))

    def send_curtain(self):
        try:
            val = float(self.ent_curt.get())
            if self.controller.cc_system.setCurtainStatus(val):
                Messagebox.show_info("Sent!", "Success")
        except: pass

if __name__ == "__main__":
    app_window = ttk.Window(themename="cyborg") 
    app = HomeAutomationMenuApp(app_window)

    app_window.mainloop()
