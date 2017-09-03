/*
	Name: Steam Bulk Config
	Version: 1.0
	Description: Bulk config steam games' settings
	
	Author: Blucifer
	Date: Sep 2, 2017
*/

/*
	Config file data format:
	
	paths: [steamapps, userdata_id]
*/

/*
	#
*/
#Warn All
#SingleInstance Force

#Include SerDes.ahk

/*
	Settings
*/
SendMode "Input"
SetWorkingDir A_ScriptDir
A_FileEncoding := "UTF-8"

/*
	Global Vars
*/
configFile := A_ScriptDir "\Steam_BulkConfig_Config.ahko"

/*
	Auto Execute
*/

if (!loadConfig()) { ; Config doesn't exist or is invalid
	if (!createConfig()) { ; Didn't create a new one
		return
	}
}

createGamesList()

bulkConfig()

return

/*
	Functions
*/
bulkConfig() {
	global gamesList
	
	g := GuiCreate(, "Steam Bulk Config", bulkConfigEvents)
	
	g.Add("Text",, "Select config options")
	
	g.Add("DropDownList", "xm Section vSteamOverlay AltSubmit Choose1", "No Change|Disabled|Enabled")
	g.Add("Text", "ys", "Steam Overlay")
	
	g.Add("DropDownList", "xm Section vTheatreSteamVR AltSubmit Choose1", "No Change|Enabled|Disabled")
	g.Add("Text", "ys", "Desktop Theatre during SteamVR")
	
	g.Add("DropDownList", "xm Section vAutoUpdate AltSubmit Choose1", "No Change|Always|Only On Launch|High Priority")
	g.Add("Text", "ys", "Auto Update")
	
	g.Add("DropDownList", "xm Section vBackgroundDls AltSubmit Choose1", "No Change|Follow Global|Always|Never")
	g.Add("Text", "ys", "Allow background downloads while running")
	
	;g.Add("DropDownList", "xm Section vSteamCloud AltSubmit Choose1", "No Change|Disabled|Enabled")
	;g.Add("Text", "ys", "Steam Cloud")
	
	g.Add("Text", "xm", "Select games to modify")
	gameSelectionBox := g.Add("ListBox", "h400 w360 vGameSelection multi")
	gameSelectionBox.Opt("-Redraw")
	for k, v in gamesList {
		gameSelectionBox.Add(k)
	}
	gameSelectionBox.Opt("+Redraw")
	
	g.Add("Button", "xm Section", "Modify All").OnEvent("Click", "modifyAll")
	g.Add("Button", "ys Default", "Modify Selected").OnEvent("Click", "modifySelected")
	
	g.Show()
}
class bulkConfigEvents {
	modifyAll(GuiCtrl) {
		global gamesList
		
		gData := GuiCtrl.Gui.Submit()
		
		ids := []
		for k, v in gamesList {
			ids.Push(v)
		}
		
		this.modify(ids, gData)
	}
	
	modifySelected(GuiCtrl) {
		global gamesList
		
		gData := GuiCtrl.Gui.Submit()
		
		ids := []
		for k, v in gData.GameSelection {
			ids.Push(gamesList[v])
		}
		
		this.modify(ids, gData)
	}
	
	modify(ids, gData) {
		modifyLocalConfigs(ids, gData.SteamOverlay-2, gData.TheatreSteamVR-2)
		modifySteamappsConfigs(ids, gData.AutoUpdate-2, gData.BackgroundDls-2)
		; modifySharedConfig(ids, gData.SteamCloud-2)
	}
}

/*
config.paths.localconfig

Steam Overlay
Theatre during SteamVR
*/
modifyLocalConfigs(ids, steamOverlay, theatreSteamVr) {
	global config
	
	if (steamOverlay = -1 && theatreSteamVr = -1) {
		return
	}
	
	; Read file
	fData := FileRead(config.paths.localconfig)
	
	; Extract apps string
	appsStart := InStr(fData, "
	(
	`t"apps"
	`t{
	`t	"vbc"		"0"
	)")
	appsEnd := InStr(fData, "`n`t`"apptickets`"")
	appsStr := SubStr(fData, appsStart, appsEnd-appsStart)
	
	; Generate new apps string
	newAppsStr := SubStr(appsStr, 1, StrLen(appsStr)-3)
	for k, id in ids { ; For each id
		idPos := InStr(appsStr, id)
		if (idPos) { ; Entry exists
			optEnd := InStr(appsStr, "}", false, idPos)
			optStr := SubStr(appsStr, idPos, optEnd-idPos+1)
		} else { ; Create new entry
			optStr := "`n`t`t`"" id "`""
				. "`n`t`t{"
				. "`n`t`t}"
			newAppsStr .= optStr
		}
		
		newOptStr := optStr
		
		; Replace all steam overlay options
		if (steamOverlay != -1) {
			overlayPos := InStr(newOptStr, "OverlayAppEnable")
			if (overlayPos) {
				overlayPos += 19
				newOptStr := SubStr(newOptStr, 1, overlayPos) . steamOverlay . SubStr(newOptStr, overlayPos+2)
			} else {
				newOptStr := SubStr(newOptStr, 1, StrLen(newOptStr)-3)
					. "`t`t`t`"OverlayAppEnable`"`t`t`"" steamOverlay "`""
					. "`n`t`t}"
			}
		}
		
		; Replace all steam vr options
		if (theatreSteamVr != -1) {
			vrPos := InStr(newOptStr, "DisableLaunchInVR")
			if (vrPos) {
				vrPos += 20
				newOptStr := SubStr(newOptStr, 1, vrPos) . theatreSteamVr . SubStr(newOptStr, vrPos+2)
			} else {
				newOptStr := SubStr(newOptStr, 1, StrLen(newOptStr)-3)
					. "`t`t`t`"DisableLaunchInVR`"`t`t`"" theatreSteamVr "`""
					. "`n`t`t}"
			}
		}
		
		newAppsStr := StrReplace(newAppsStr, optStr, newOptStr)
	}
	newAppsStr .= "`n`t}"
	
	; New data for file
	newFData := StrReplace(fData, appsStr, newAppsStr)
	
	f := FileOpen(config.paths.localconfig, "w")
	f.Write(newFData)
	f.Close()
}

/*
config.paths.steamapps "\appmanifest_[GAME_ID].acf"

Auto Update
Background downloads while running
*/
modifySteamappsConfigs(ids, autoUpdate, backgroundDls) {
	global config
	
	if (autoUpdate = -1 && backgroundDls = -1) {
		return
	}
	
	for k, id in ids {
		file := config.paths.steamapps "\appmanifest_" id ".acf"
		
		; Read file
		fData := FileRead(file)
		
		; Replace autoupdate option
		if (autoUpdate != -1) {
			autoUpdatePos := InStr(fData, "AutoUpdateBehavior")
			if (!autoUpdatePos) {
				continue
			}
			autoUpdatePos += 21
			fData := SubStr(fData, 1, autoUpdatePos) . autoUpdate . SubStr(fData, autoUpdatePos+2)
		}
		
		; Replace background dl option
		if (backgroundDls != -1) {
			backgroundDlPos := InStr(fData, "AllowOtherDownloadsWhileRunning")
			if (!backgroundDlPos) {
				continue
			}
			backgroundDlPos += 34
			fData := SubStr(fData, 1, backgroundDlPos) . backgroundDls . SubStr(fData, backgroundDlPos+2)
		}
		
		; Overwrite with new data
		f := FileOpen(file, "w")
		f.Write(fData)
		f.Close()
	}
}

/*
config.paths.sharedconfig

Steam Cloud
*/
; This attempted to update the cloud settings but they were reverted on restart.
; Probably due to sync with steam servers
modifySharedConfig(ids, steamCloud) {
	global config
	
	if (steamCloud = -1) {
		return
	}
	
	; Read file
	fData := FileRead(config.paths.sharedconfig)
	
	; Replace all required options
	for k, id in ids {
		startPos := InStr(fData, id)
		endPos := InStr(fData, "`n`t`t`t`t`t}", false, startPos)
		part := SubStr(fData, startPos, endPos-startPos)
		
		cloudPos := InStr(part, "cloudenabled")
		if (cloudPos) {
			cloudPos += 15
			newPart := SubStr(part, 1, cloudPos) . steamCloud . SubStr(part, cloudPos+2)
			fData := StrReplace(fData, part, newPart)
		}
	}
	
	; Overwrite with new data
	f := FileOpen(config.paths.sharedconfig, "w")
	f.Write(fData)
	f.Close()
}

; ---

createGamesList() {
	global config, gamesList
	
	gamesList := {}
	Loop Files, config.paths.steamapps "\*.acf" {
		; Get ID from file name
		id := SubStr(A_LoopFileName, 13)
		id := SubStr(id, 1, StrLen(id)-4)
		
		Loop Read, A_LoopFileFullPath {
			if (A_Index = 5) {
				; Get name from line #5
				name := SubStr(A_LoopReadLine, 11)
				name := SubStr(name, 1, StrLen(name)-1)
				
				; Store info in obj and break
				gamesList[name] := id
				break
			}
		}
	}
}

createConfig() {
	global configFile, config
	
	config := { paths: [] }
	
	; Ask for steamapps dir
	config.paths.steamapps := DirSelect("*C:\Program Files (x86)\Steam\steamapps", 3, "Locate steamapps directory")
	if (ErrorLevel) {
		return false
	}
	
	config.paths.userdata_id := DirSelect("*C:\Program Files (x86)\Steam\userdata", 3, "Locate `"...\Steam\userdata\[YOUR_USERID]`"")
	if (ErrorLevel) {
		return false
	}
	config.paths.localconfig := config.paths.userdata_id "\config\localconfig.vdf"
	config.paths.sharedconfig := config.paths.userdata_id "\7\remote\sharedconfig.vdf"
	
	; Save
	SerDes(config, configFile, 1)
	return true
}

loadConfig() {
	global configFile, config
	
	if (!FileExist(configFile)) {
		return false
	}
	
	; Load
	config := SerDes(configFile)
	
	; Validate
	if (!config.paths || !DirExist(config.paths.steamapps)
		|| !DirExist(config.paths.userdata_id)
		|| !DirExist(config.paths.localconfig)
		|| !DirExist(config.paths.sharedconfig)) {
		return false
	}
	
	return true
}
