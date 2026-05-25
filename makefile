ifneq ("$(wildcard $(TOOLBOX_FILE))","")
        CE := flatpak-spawn --host podman
else
        CE := /usr/bin/podman
endif

include source/source.mk container/container.mk

kernel:
	${CE} run -it --rm \
	  -v .:/home/workspace \
	  -w /home/workspace \
	  -u root \
	  --network host \
	  es_debian \
	  make source-kernel
