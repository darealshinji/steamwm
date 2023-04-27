BINS = wmctrl steamwm.so

GLIB_CFLAGS := $(shell PKG_CONFIG_PATH="/usr/lib/i386-linux-gnu/pkgconfig:/usr/lib32/pkgconfig:$PKG_CONFIG_PATH" pkg-config --cflags glib-2.0)
CFLAGS      := -m32 -O3 -Wall
LDFLAGS     := -s


all: $(BINS)

clean:
	-rm -f $(BINS) steam.log

steamwm.so: steamwm.cpp
	g++ --shared -fPIC -fvisibility=hidden $(CFLAGS) -o $@ $< -lX11 -static-libgcc -static-libstdc++ $(LDFLAGS)

wmctrl: wmctrl.c
	gcc $(CFLAGS) $(GLIB_CFLAGS) -o $@ $< -lX11 -lglib-2.0 $(LDFLAGS)

