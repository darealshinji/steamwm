BINS = wmctrl steamwm.so


all: $(BINS)

clean:
	-rm -f $(BINS)

steamwm.so: steamwm.cpp
	g++ --shared -m32 -O3 -Wall -fPIC -o $@ $< -Wl,--as-needed -lX11 -lglib-2.0 -static-libgcc -static-libstdc++ -s

wmctrl: wmctrl.c
	gcc -m32 -O3 -Wall $(shell pkg-config --cflags glib-2.0) -o $@ $< -lX11 -lglib-2.0 -s

