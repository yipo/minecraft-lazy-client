
packing:

# If no specified, the default target is `packing'.


SOURCE_DIR ?= source

# The place to put all materials (.jar or .zip) in.
# It works if you put materials in .\, but it's not recommended.

LAUNCHER_JAR ?= minecraft.jar

# The default value is the filename of the .jar official launcher.
# The .exe version is also OK. However, the .jar version has a smaller size.

MOD_LIST ?=

# - Syntax:
# MOD_LIST = [<target> ...]
# <target> = <mod-name>.<method>
# <method> = mod | mlm

# - Example:
# MOD_LIST = ModLoader.mod OptiFine.mod InvTweaks.mlm ReiMinimap.mlm

# If MOD_LIST is empty, no mod will be installed,
# `first-run' will not be executed and just a portable Minecraft will you get.

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

OUTPUT_FILE ?= MinecraftLazyClient.7z

# The name of the output file.
# Note that the filename extension will affect the way 7za compresses the file.

PACKING ?=

# - Syntax:
# PACKING = [$(<predef-const>) ...] [<file-path> ...]
# <predef-const> = PL_SETT | PL_SERV | PL_SAVE | PL_TXPK

# - Example:
# PACKING = $(PL_SETT) $(PL_SERV) .minecraft\config\InvTweaks*.txt

# The additional files or folders you want to add in the package.
# Specify the path related to $(mc_dir). The constants below can also be used:

# PL_SETT: the file record the settings.
# PL_SERV: the file record the server list.
# PL_SAVE: the `save' folder.
# PL_TXPK: the `texturepacks' folder.

PL_SETT = .minecraft\options.txt
PL_SERV = .minecraft\servers.dat
PL_SAVE = .minecraft\saves
PL_TXPK = .minecraft\texturepacks

# Note that placing '\' at end of a line means splitting lines.


PHONY: initial portable-basis first-run install-mods post-processing packing
PHONY: uninstall-mods packing-clean clean

.SUFFIXES:
.SUFFIXES: %.mod %.mlm

SHELL = cmd.exe

VPATH = $(SOURCE_DIR)

mc_dir = MinecraftLazyClient
mc_lch = $(mc_dir)\.minecraft\launcher.jar
mc_bat = $(mc_dir)\Minecraft.bat
mc_jar = $(mc_dir)\.minecraft\bin\minecraft.jar
mc_mod = $(mc_dir)\.minecraft\mods

# Just for a shorter name

define \n


endef

# The new line character.

fix_path = $(subst /,\,$1)

# The function that convert a path in Unix style to the one in Windows style.

touch = copy /B $1+,, $1 > nul

# The command that change the date and time of a file as `touch' on Unix.
# Reference: http://technet.microsoft.com/en-us/library/bb490886

ok_msg = @echo [$1] OK

java_arg = -Xms512M -Xmx1024M

# The arguments for `java' command used by the whole script.
# The setting `-Xms512M -Xmx1024M' should be a good choice.

run_mc = $(mc_bat) /WAIT

# Run Minecraft via $(mc_bat) consistently but wait for termination.


initial: $(SOURCE_DIR) tool\7za.exe

$(SOURCE_DIR):
	md $@

# This will create a $(SOURCE_DIR) folder if there is no one yet.

tool:
	md $@

tool\7za.exe: | tool
	@echo ** 7za (can be got from: http://www.7-zip.org/) is needed.
	@echo ** Put the 7za.exe in tool\ folder.
	@exit 1

# It's wired to use this script without extracting or creating any archive.


portable-basis: initial $(mc_lch) $(mc_bat)
	$(call ok_msg,$@)

$(mc_dir):
	md $@
$(mc_dir)\.minecraft: | $(mc_dir)
	md $@

# Hide the launcher.jar in `.minecraft' folder
# so that nobody will execute it directly by mistake (I thought).

$(mc_lch): $(LAUNCHER_JAR) | $(mc_dir)\.minecraft
	copy /Y $(call fix_path,$<) $@ > nul

# Update when there is a newer $(LAUNCHER_JAR).

$(mc_bat): | $(mc_dir)
	>  $@ echo @ECHO OFF
	>> $@ echo SET APPDATA=%%~dp0
	>> $@ echo CD "%%~dp0\.minecraft"
	>> $@ echo START %%* javaw $(java_arg) -jar launcher.jar

# Sure, only the first line is beginning with `>'. The others are `>>'.
# Using %~dp0 so that it doesn't matter where the current directory is.
# Using %* so that we can add the argument /WAIT to the START command.


first-run: $(mc_jar).bak
	$(call ok_msg,$@)

# This step is annoying and wasting time.
# So once it has been done, it will not update anymore.
# When update is really needed, just `make clean' and do it all again.

$(mc_jar): | portable-basis
	@echo ** Please login, take the first run and quit the game manually.
	$(run_mc)

$(mc_jar).bak: $(mc_jar)
	$(if $(wildcard $@),                 \
		@echo ** Restore $(mc_jar).$(\n) \
		@copy /Y $@ $< > nul$(\n)        \
		@$(call touch,$@),               \
		copy $< $@ > nul)

# Backup and restore $(mc_jar):
# If $(mc_jar).bak does not exist yet, backup $(mc_jar) to $(mc_jar).bak.
# Otherwise, restore $(mc_jar) from $(mc_jar).bak if $(mc_jar) is newer.


PHONY: -im-mod-clean -im-mod -im-mlm-clean -im-mlm

# It's not recommended to execute these targets directly.

im_mod = $(filter %.mod,$(MOD_LIST))
im_mlm = $(filter %.mlm,$(MOD_LIST))

install-mods: portable-basis $(if $(MOD_LIST),first-run)
install-mods: $(if $(im_mod),-im-mod-clean -im-mod)
install-mods: $(if $(im_mlm),-im-mlm-clean -im-mlm)

uninstall-mods: -im-mod-clean -im-mlm-clean

# Execute the `uninstall-mods' target to remove all the installed mods.


-im-mod-clean: $(mc_jar).bak
	-rd /S /Q extract

# Use $(mc_jar).bak as a prerequisite to restore $(mc_jar).

-im-mod: $(im_mod)
	-copy extract\*.jar $(mc_dir)\.minecraft\bin > nul
	cd extract && 7za a $(CURDIR)\$(mc_jar) * -x!*.jar > nul
	7za d $(mc_jar) META-INF > nul
	$(call ok_msg,$@)

# Installation of manual-install mods:
# - Only .jar files (if any) will be copied to $(mc_dir)\.minecraft\bin.
# - The others will be added in $(mc_jar).
# - The `META-INF' folder in $(mc_jar) will be deleted.

extract:
	md $@

$(im_mod): | extract

%.mod:
	@echo [$@] $<
	7za x $(call fix_path,$<) -oextract -y > nul

# The order of targets in MOD_LIST does matter.
# If any files are conflicted, the former will be overwrite by the latter.


-im-mlm-clean:
	-rd /S /Q $(mc_mod)

-im-mlm: $(im_mlm)
	$(call ok_msg,$@)

$(mc_mod):
	md $@

$(im_mlm): | $(mc_mod)

%.mlm:
	@echo [$@] $<
	copy $(call fix_path,$<) $(mc_mod) > nul

# Installation of the mods require ModLoader:
# Simply copy the .zip file to $(mc_mod).

# Make sure ModLoader is also installed if there are mods depend on it.
# This script will not check this for you.


auto_match_pattern = $(SOURCE_DIR)/*$(basename $(notdir $1))*.*

# Find the `*<mod-name>*.zip' file in $(SOURCE_DIR) folder.

auto_match = $1: $(lastword $(wildcard $(call auto_match_pattern,$1)))

# Take the last one in alphabetical order.

$(foreach i,$(MOD_LIST),$(eval $(call auto_match,$(i))))


post-processing:

# Users can do something before packing.
# Note that don't let this target become the default target.
# (i.e. This target should not be the first target in your makefile.)
# (Or just define this target below the include statement of this makefile.)

# The variables in this makefile like $(mc_dir), $(\n), $(ok_msg), etc
# can be used in the user-defined recipes.
# Running Minecraft again, use $(run_mc).


packing: install-mods post-processing packing-clean $(OUTPUT_FILE)

packing-clean:
	-del $(OUTPUT_FILE) Packing.list

$(OUTPUT_FILE): Packing.list
	7za a $@ @Packing.list

Packing.list:
	>  $@ echo $(mc_dir)\.minecraft\bin
	>> $@ echo $(mc_dir)\.minecraft\mods\*.zip
	>> $@ echo $(mc_dir)\.minecraft\mods\*.jar
	>> $@ echo $(mc_lch)
	>> $@ echo $(mc_bat)
	$(foreach i,$(PACKING),>> $@ echo $(mc_dir)\$(i)$(\n))

# Actually, only few things are needed to make a package.


clean: packing-clean
	-rd /S /Q $(mc_dir) extract

super-clean: clean
	-rd /S /Q tool $(SOURCE_DIR)
