# Minecraft Lazy Client
# (for the launcher of Minecraft version >= 1.6.1)
# GitHub: https://github.com/yipo/minecraft-lazy-client
# Author: Yi-Pu Guo (YiPo)
# License: MIT


packing:

# If no specified, the default target is `packing'.


SOURCE_DIR ?= source

# The place to put all materials (.jar or .zip) in.
# It works if you put materials in .\, but it's not recommended.

LAUNCHER_JAR ?= minecraft.jar

# The default value is the filename of the .jar official launcher.
# The .exe version is also OK. However, the .jar version has a smaller size.

BASED_ON_VER ?= 1.6.1

# The version you want to install mods on.

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
# <predef-const> = PL_SETT | PL_SERV | PL_SAVE | PL_RSPK

# - Example:
# PACKING = $(PL_SETT) $(PL_SERV) .minecraft\config\InvTweaks*.txt

# The additional files or folders you want to add in the package.
# Specify the path related to $(mc_dir). The constants below can also be used:

# PL_SETT: the file record the settings.
# PL_SERV: the file record the server list.
# PL_SAVE: the `save' folder.
# PL_RSPK: the `resourcepacks' folder.

PL_SETT = .minecraft\options.txt
PL_SERV = .minecraft\servers.dat
PL_SAVE = .minecraft\saves
PL_RSPK = .minecraft\resourcepacks

# Note that placing '\' at end of a line means splitting lines.

JAVA_ARGS ?=

# To set `JVM Arguments' in the profile editor.


.PHONY: initial portable-basis first-run install-mods post-processing packing
.PHONY: uninstall-mods packing-clean clean super-clean

.SUFFIXES:
.SUFFIXES: %.mod %.mlm

SHELL = cmd.exe

VPATH = $(SOURCE_DIR)

mc_dir = MinecraftLazyClient
mc_bat = $(mc_dir)\Minecraft.bat
mc_lch = $(mc_dir)\.minecraft\mc-launcher.jar
mc_pfl = $(mc_dir)\.minecraft\launcher_profiles.json
mc_lib = $(mc_dir)\.minecraft\libraries
mc_ver = $(mc_dir)\.minecraft\versions
mc_mod = $(if $(forge),$(mc_mod_fg),$(mc_mod_ml))

# Just for shorter names

forge = $(findstring Forge,$(BASED_ON_VER))

mc_lib_fg = $(mc_lib)\net\minecraftforge

mc_mod_fg = $(mc_dir)\.minecraft\mods
mc_mod_ml = $(des_dir)\mods

# The location of `mods' folder of ModLoader is different from the Forge one.
# If there is a keyword `ModLoader' in $(MOD_LIST),
# $(mc_mod) will become `$(des_dir)\mods' automatically.
# I hope this can be unify in the future.

ori = $(firstword $(subst -, ,$(BASED_ON_VER)))
sou = $(BASED_ON_VER)
des = $(ori)-mlc

ori_dir = $(mc_ver)\$(ori)
sou_dir = $(mc_ver)\$(sou)
des_dir = $(mc_ver)\$(des)

sou_jar = $(sou_dir)\$(sou).jar
sou_jsn = $(sou_dir)\$(sou).json
des_jar = $(des_dir)\$(des).jar
des_jsn = $(des_dir)\$(des).json

# This script will create a new version $(des) based on $(sou).

define \n


endef

# The new line character.

fix_path = $(subst /,\,$1)

# The function that convert a path in Unix style to the one in Windows style.

ok_msg = @echo [$1] OK

run_mc = $(mc_bat) /WAIT

# Run Minecraft via $(mc_bat) consistently but wait for termination.


initial: $(SOURCE_DIR) tool\7za.exe tool\jq.exe
	$(call ok_msg,$@)

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

tool\jq.exe: | tool
	@echo ** jq (can be got from: http://stedolan.github.io/jq/) is needed.
	@echo ** Put the jq.exe in tool\ folder.
	@exit 1

# The tool to dealing with .json files.


portable-basis: initial $(mc_lch) $(mc_bat)
	$(call ok_msg,$@)

$(mc_dir):
	md $@
$(mc_dir)\.minecraft: | $(mc_dir)
	md $@

# Hide the mc-launcher.jar in `.minecraft' folder
# so that nobody will execute it directly by mistake (I thought).

$(mc_lch): $(LAUNCHER_JAR) | $(mc_dir)\.minecraft
	copy /Y $(call fix_path,$<) $@ > nul

# Update when there is a newer $(LAUNCHER_JAR).

$(mc_bat): | $(mc_dir)
	>  $@ echo @ECHO OFF
	>> $@ echo SET APPDATA=%%~dp0
	>> $@ echo CD "%%~dp0\.minecraft"
	>> $@ echo START %%* javaw -jar mc-launcher.jar

# Sure, only the first line is beginning with `>'. The others are `>>'.
# Using %~dp0 so that it doesn't matter where the current directory is.
# Using %* so that we can add the argument /WAIT to the START command.


first-run: portable-basis restore
	$(call ok_msg,$@)

# This step is annoying and wasting time.
# So once it has been done, it will not update anymore.
# When update is really needed, just `make clean' and do it all again.

$(ori_dir): | portable-basis
	@echo ** Please login, take the first run of the version $(ori)
	@echo ** and then quit the game manually.
	$(run_mc)

$(mc_lib_fg): $(ori_dir) | $(SOURCE_DIR)/forge-*-*-installer.jar
	@echo ** Please install Forge.
	set APPDATA=$(mc_dir)&& javaw -jar $(lastword $|)

# Note that `&&' must right behind the $(mc_dir), or
# any space will cause the value of APPDATA wrong.

$(sou_dir): $(if $(forge),$(mc_lib_fg))

restore: $(sou_dir) $(if $(wildcard $(des_dir)),$(des_jar) $(des_jsn))
	@echo ** Restore the version $(des) to a pure one.
	-md $(des_dir) > nul
	copy /Y $(sou_jar) $(des_jar) > nul
	jq ".id = \"$(des)\"" < $(sou_jsn) > $(des_jsn)
	@echo ** Update the restore timestamp.
	> $@ echo.

# The `restore' target restore $(des) to a pure one only if that was modified.


install-mods uninstall-mods: $(if $(MOD_LIST),first-run,portable-basis)
	$(call ok_msg,$@)

.PHONY: -im-mod-clean -im-mod -im-mlm-clean -im-mlm

# It's not recommended to execute these targets directly.

im_mod = $(filter %.mod,$(MOD_LIST))
im_mlm = $(filter %.mlm,$(MOD_LIST))

install-mods: $(if $(im_mod),-im-mod-clean -im-mod)
install-mods: $(if $(im_mlm),-im-mlm-clean -im-mlm)

uninstall-mods: -im-mod-clean -im-mlm-clean

# Execute the `uninstall-mods' target to remove all the installed mods.


-im-mod-clean:
	-rd /S /Q extract

-im-mod: $(im_mod)
	-copy extract\*.jar $(des_dir) > nul
	cd extract && 7za a $(CURDIR)\$(des_jar) * -x!*.jar > nul
	7za d $(des_jar) META-INF > nul
	$(call ok_msg,$@)

# Installation of manual-install mods:
# - Only .jar files (if any) will be copied to $(des_dir).
# - The others will be added in $(des_jar).
# - The `META-INF' folder in $(des_jar) will be deleted.

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


post-processing: install-mods

# Users can do something before packing.
# Note that don't let this target become the default target.
# (i.e. This target should not be the first target in your makefile.)
# (Or just define this target below the include statement of this makefile.)

# The variables in this makefile like $(mc_dir), $(\n), $(ok_msg), etc
# can be used in the user-defined recipes.
# Running Minecraft again, use $(run_mc).


packing: install-mods post-processing packing-clean $(OUTPUT_FILE)
	$(call ok_msg,$@)

packing-clean:
	-del $(OUTPUT_FILE) packing-list

$(OUTPUT_FILE): packing-list default-profile
	-7za a $@ @packing-list

# Ignore file-not-found warnings by adding the leading hyphen.

ifneq ($(forge),)
PACKING += .minecraft\libraries\net\minecraftforge
PACKING += .minecraft\libraries\org\scala-lang
PACKING += .minecraft\libraries\com\typesafe
JAVA_ARGS += -Dfml.ignoreInvalidMinecraftCertificates=true
JAVA_ARGS += -Dfml.ignorePatchDiscrepancies=true
endif

packing-list:
	>  $@ echo $(des_dir)
	>> $@ echo $(mc_mod)\*.zip
	>> $@ echo $(mc_mod)\*.jar
	>> $@ echo $(mc_pfl)
	>> $@ echo $(mc_lch)
	>> $@ echo $(mc_bat)
	$(foreach i,$(PACKING),>> $@ echo $(mc_dir)\$(i)$(\n))

# Actually, only few things are needed to make a package.

define dfpfl_jq
{
  profiles: {
    "(Default)": {
      name: "(Default)",
      lastVersionId: "$(des)",
      javaArgs: "$(JAVA_ARGS)"
    }
  },
  selectedProfile: "(Default)",
  clientToken,
  authenticationDatabase: {}
}
endef

default-profile: $(mc_pfl)
	jq "$(subst $(\n),,$(subst ",\",$(dfpfl_jq)))" < $< > $@
	type $@ > $<
	del $@

# Remove private information and set the selected version.

$(mc_pfl):
	> $@ echo.

# Create a dummy file, if $(mc_pfl) does not exist.


clean: packing-clean
	-rd /S /Q $(mc_dir) extract
	-del restore

super-clean: clean
	-rd /S /Q tool $(SOURCE_DIR)

