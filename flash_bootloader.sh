# This script temporarily patches the Makefile and linker script to enable
# uploading a compiled program to address 0x20000000 instead of the usual
# 0x20400000, and then builds and uploads the bootloader using this modification.
#
# The changes are then reverted and the demo program is build and uploaded.

if [ $(basename $(pwd)) != "freedom-e-sdk" ]; then
    echo This script must be run from inside the freedom-e-sdk directory
    exit 1
fi

TFILE=$(mktemp tmp.tar.XXXXXXXXX)
TPATCH=$(mktemp tmp.patch.XXXXXXXXX)

if ! tar czf $TFILE Makefile bsp/env/freedom-e300-hifive1/flash.lds; then
    echo ERROR Could not save files
    rm -f $TFILE $TPATCH
    exit 1
fi

cat >$TPATCH <<'EOF'
diff --git a/Makefile b/Makefile
index 6b8e1c6..f7c22d9 100644
--- a/Makefile
+++ b/Makefile
@@ -1,4 +1,4 @@
-#############################################################
+############################################################
 # Configuration
 #############################################################
 
@@ -189,6 +189,12 @@ $(openocd_builddir)/configure.stamp:
 openocd-clean:
        rm -rf $(openocd_builddir)
 
+.PHONY: check-tools
+check-tools:
+	@$(RISCV_GCC) --version | grep gcc || (echo ERROR RISCV gcc not found; exit 1)
+	@$(RISCV_GDB) --version | grep configured  || (echo ERROR RISCV gdb not found; exit 1)
+	@$(RISCV_OPENOCD) --version 2>&1 | grep Debugger  || (echo ERROR RISCV OpenOCD not found; exit 1)
+
 #############################################################
 # This Section is for Software Compilation
 #############################################################
@@ -218,7 +224,7 @@ GDB_UPLOAD_ARGS ?= --batch
 GDB_UPLOAD_CMDS += -ex "set remotetimeout 240"
 GDB_UPLOAD_CMDS += -ex "target extended-remote localhost:$(GDB_PORT)"
 GDB_UPLOAD_CMDS += -ex "monitor reset halt"
-GDB_UPLOAD_CMDS += -ex "monitor flash protect 0 64 last off"
+GDB_UPLOAD_CMDS += -ex "monitor flash protect 0 0 last off"
 GDB_UPLOAD_CMDS += -ex "load"
 GDB_UPLOAD_CMDS += -ex "monitor resume"
 GDB_UPLOAD_CMDS += -ex "monitor shutdown"
diff --git a/bsp/env/freedom-e300-hifive1/flash.lds b/bsp/env/freedom-e300-hifive1/flash.lds
index 6b37141..faa9c65 100644
--- a/bsp/env/freedom-e300-hifive1/flash.lds
+++ b/bsp/env/freedom-e300-hifive1/flash.lds
@@ -4,7 +4,7 @@ ENTRY( _start )
 
 MEMORY
 {
-  flash (rxai!w) : ORIGIN = 0x20400000, LENGTH = 512M
+  flash (rxai!w) : ORIGIN = 0x20000000, LENGTH = 512M
   ram (wxa!ri) : ORIGIN = 0x80000000, LENGTH = 16K
 }
EOF

if ! patch --dry-run -f -p1 <$TPATCH; then
    echo ERROR patch failed
    rm -f $TFILE $TPATCH
    exit 1
fi
patch -p1 <$TPATCH

if ! make check-tools; then
    echo ERROR The toolchain and utility programs could not be found
    echo If you installed pre-built tools, please set RISCV_PATH and RISCV_OPENOCD_PATH correctly
    echo Otherwise, please be sure you git cloned with --recursive and run "make tools"
    tar xzf $TFILE
    rm -f $TFILE $TPATCH
    exit 1
fi

if ! make software PROGRAM=double_tap_dontboot BOARD=freedom-e300-hifive1; then
    echo ERROR Build of bootloader failed
    tar xzf $TFILE
    rm -f $TFILE $TPATCH
    exit 1
fi

if ! make upload PROGRAM=double_tap_dontboot BOARD=freedom-e300-hifive1; then
    echo ERROR Upload of bootloader failed
    tar xzf $TFILE
    rm -f $TFILE $TPATCH
    exit 1
fi

tar xzf $TFILE
rm -f $TFILE $TPATCH

if ! make software PROGRAM=led_fade BOARD=freedom-e300-hifive1; then
    echo ERROR Build of led_fade failed
    exit 1
fi

if ! make upload PROGRAM=led_fade BOARD=freedom-e300-hifive1; then
    echo ERROR Upload of led_fade failed
    exit 1
fi

echo Your SPI Flash has been programmed sucessfully
