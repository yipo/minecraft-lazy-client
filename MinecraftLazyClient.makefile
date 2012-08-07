
SOURCE_DIR ?= source
LAUNCHER_JAR ?= minecraft.jar
MOD_LIST ?=

# SOURCE_DIR: (Optional)
# The place to put all materials (.jar or .zip) in.
# It works if you put materials in .\, but it's not recommended.

# LAUNCHER_JAR: (Optional)
# The default value is the filename of the .jar official launcher.
# The .exe version is also OK. However, the .jar version has a smaller size.

# MOD_LIST: (Optional)
# If MOD_LIST is empty, no mod will be installed,
# `first-run' will not be executed and just a portable Minecraft will you get.

# - Syntax:
# MOD_LIST = [<target> ...]
# <target> = <mod-name>.<method>
# <method> = mod | mlm

# - Example:
# MOD_LIST = ModLoader.mod OptiFine.mod ReiMinimap.mlm InvTweaks.mlm

# ** mod-name: the name of the mod.
# By default, this script will find the `*<mod-name>*.zip' for installation.
# Ex: `ReiMinimap.mlm' can match the file `[1.3.1]ReiMinimap_v3.2_05.zip'.

# If multiple .zip file are matched, the last one in alphabetical order
# (usually the newest one in version) will be chosen.

# If no file is matched or the file matched is not you want,
# write a rule to specify the file name.
# Ex: ReiMinimap.mlm: TheFileYouWant.zip

# ** method: the way to install the mod.
# mod: for normal mods (add the .class files in `bin\minecraft.jar').
# mlm: for mods require ModLoader (copy the .zip file to the `mods' folder).


PHONY: initial portable-basis first-run install-mods packing
PHONY: uninstall-mods clean

.SUFFIXES:
.SUFFIXES: %.mod %.mlm

VPATH = $(SOURCE_DIR)

mc_dir = MinecraftLazyClient
mc_lch = $(mc_dir)\launcher\launcher.jar
mc_bat = $(mc_dir)\Minecraft.bat
mc_jar = $(mc_dir)\.minecraft\bin\minecraft.jar
mc_mod = $(mc_dir)\.minecraft\mods

# Just for a shorter name

define \n


endef

# The new line character.

fix_path = $(subst /,\,$1)

# The function that convert a path in Unix style to the one in Windows style.

touch = copy /B $1+,, $1

# The command that change the date and time of a file as `touch' on Unix.
# Reference: http://technet.microsoft.com/en-us/library/bb490886


initial: $(SOURCE_DIR) tool\7za.exe

$(SOURCE_DIR):
	md $@

# This will create a $(SOURCE_DIR) for you if you don't have one yet.

tool:
	md $@

tool\7za.exe: | tool
	@echo ** 7za (can be got from: http://www.7-zip.org/) is needed.
	@echo ** Put the 7za.exe in tool\ folder.
	@exit 1

# It is wired to use this script without extracting or creating any archive.


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


first-run: $(mc_jar).bak

# This step is annoying and wasting time.
# No one wants to do it again and again.
# So once it has been done, it will not update anymore.
# When update is really needed, just `make clean' and do it all again.

$(mc_jar): | portable-basis
	@echo ** Please login, take the first run and quit the game manually.
	set APPDATA=$(mc_dir)&& javaw -Xms512M -Xmx1024M -jar $(mc_lch)

# Note that `&&' must right behind the $(mc_dir), or
# any space will cause the value of APPDATA wrong.

$(mc_jar).bak: $(mc_jar)
	$(if $(wildcard $@),copy /Y $@ $<$(\n)$(call touch,$@),copy $< $@)

# Backup and restore $(mc_jar):
# If $(mc_jar).bak does not exist yet, backup $(mc_jar) to $(mc_jar).bak.
# Otherwise, restore $(mc_jar) from $(mc_jar).bak if $(mc_jar) is newer.


PHONY: -im-mod-clean -im-mod -im-mlm-clean -im-mlm

# It's not recommended to execute these target directly.

im_mod = $(filter %.mod,$(MOD_LIST))
im_mlm = $(filter %.mlm,$(MOD_LIST))

install-mods: portable-basis $(if $(MOD_LIST),first-run)
install-mods: $(if $(im_mod),-im-mod-clean -im-mod)
install-mods: $(if $(im_mlm),-im-mlm-clean -im-mlm)

uninstall-mods: -im-mod-clean -im-mlm-clean

# Execute the `uninstall-mods' target to remove all installed mods.


-im-mod-clean: $(mc_jar).bak
	-rd /S /Q extract

# Use $(mc_jar).bak as a prerequisite to restore $(mc_jar).

-im-mod: $(im_mod)
	-copy extract\*.jar $(mc_dir)\.minecraft\bin
	cd extract && 7za a $(CURDIR)\$(mc_jar) * -x!*.jar > nul
	7za d $(mc_jar) META-INF > nul

# Installation of manual-install mods:
# - Only .jar files (if any) will be copied to $(mc_dir)\.minecraft\bin.
# - The others will be added in $(mc_jar).
# - The `META-INF' folder in $(mc_jar) will be deleted.

extract:
	md $@

$(im_mod): | extract

%.mod:
	7za e $(call fix_path,$<) -oextract -y > nul

# The order of targets in MOD_LIST does matter.
# If any files are conflicted, the former will be overwrite by the latter.


-im-mlm-clean:
	-rd /S /Q $(mc_mod)

-im-mlm: $(im_mlm)
	@rem

$(mc_mod):
	md $@

$(im_mlm): | $(mc_mod)

%.mlm:
	copy $(call fix_path,$<) $(mc_mod)

# Installation of ModLoader mods:
# Simply copy the .zip files to $(mc_mod).

# Make sure ModLoader is also installed if there are mods depend on it.
# This script will not check this for you.


auto_match_pattern = $(SOURCE_DIR)/*$(basename $(notdir $1))*.zip

# Find the `*<mod-name>*.zip' file in $(SOURCE_DIR) folder.

auto_match = $1: $(lastword $(wildcard $(call auto_match_pattern,$1)))

# Take the last one in alphabetical order.

$(foreach i,$(MOD_LIST),$(eval $(call auto_match,$(i))))


packing:

clean:
	-rd /S /Q $(mc_dir) extract

