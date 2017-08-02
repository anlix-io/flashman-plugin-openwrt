1) Always remove .config file before compiling for different targets
2) Always apply diffconfig with the following steps.
	2.1) cp diffconfig .config
	2.2) make defconfig
3) Run make menuconfig and
	3.1) Select target device
	3.2) Select flashman-plugin package on Utilities
