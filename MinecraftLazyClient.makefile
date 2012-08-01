
SOURCE_DIR ?= source
LAUNCHER_JAR ?= minecraft.jar
MOD_LIST ?=

# SOURCE_DIR: (Optional)
# The place to put all materials (.jar or .zip) in.
# It works if you put materials in .\, but it's not recommended.

# LAUNCHER_JAR: (Optional)
# The default value is the filename of the .jar official launcher.
# The .exe version is also OK. However, the .jar version has a smaller size.


PHONY: initial portable-basis first-run install-mods packing clean

VPATH = $(SOURCE_DIR)

mc_dir = MinecraftLazyClient
mc_lch = $(mc_dir)\launcher\launcher.jar
mc_bat = $(mc_dir)\Minecraft.bat
mc_jar = $(mc_dir)\.minecraft\bin\minecraft.jar

# Just for a shorter name

fix_path = $(subst /,\,$1)

# The function that convert a path in Unix style to the one in Windows style.


initial: | $(SOURCE_DIR)

$(SOURCE_DIR):
	md $@

# This will create a $(SOURCE_DIR) for you if you don't have one yet.


portable-basis: initial $(mc_lch) $(mc_bat)

$(mc_dir):
	md $@
$(mc_dir)\launcher: | $(mc_dir)
	md $@

# Hide the launcher.jar in `launcher' folder
# so that nobody will execute it directly by mistake (I think).

$(mc_lch): $(LAUNCHER_JAR) | $(mc_dir)\launcher
	copy /Y $(call fix_path,$<) $@

# Update when there is a newer $(LAUNCHER_JAR).

$(mc_bat): | $(mc_dir)
	>  $@ echo @ECHO OFF
	>> $@ echo SET APPDATA=%%~dp0
	>> $@ echo START javaw -Xms512M -Xmx1024M -jar %%~dp0\launcher\launcher.jar

# Sure, only the first line is beginning with `>'. The others are `>>'.
# The parameter `-Xms512M -Xmx1024M' should be a good choice.
# Add %APPDATA% in front of the path to the .jar file
# so that it doesn't matter where the current directory is.


first-run:

install-mods:

packing:

clean:

