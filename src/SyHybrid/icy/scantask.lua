require "SyMini"

function updateprogress(pos,max)
	task:setprogress(pos,max)
end

function sitemapupdate(t)
  runtabcmd('treeseturls', t.urls)
  runtabcmd('treesetaffecteditems',hs.vulnurls)
end

function statsupdate(t)
  runtabcmd('resupdatehtml', t.csv)
end

function addthreat(v)
  local loc = v.location
  if v.locationsrc ~= '' then
    -- replace by source code location
    loc = v.locationsrc
  end
  print(string.format('Found: %s',v.checkname))
  local j = ctk.json.object:new()
  j.caption = v.checkname
  j.subitemcount = 5
  j.subitem1 = v.location
  j.subitem2 = v.web_layer
  j.subitem3 = v.exfilrecords
  j.subitem4 = v.risk
  j.subitem5 = v.filename
  j.imageindex = 0
  local risk = string.lower(v.risk)
  if risk == 'high' then
    j.imageindex = 21
  elseif risk == 'medium' then
    j.imageindex = 22
  elseif risk == 'low' then
    j.imageindex = 23
  elseif risk == 'info' then
    j.imageindex = 24
  end
  local jsonstr = tostring(j)
  j:release()
  --hs:logcustomalert(ctk.base64.encode(jsonstr))
  runtabcmd('resaddcustomitem', jsonstr)
  runtabcmd('treesetaffecteditems',hs.vulnurls)
end

function log(s)
  outputmsg(s,-1) -- Adds to messages listview
  runtabcmd('setstatus',s) -- Updates the tab status bar text
end

function printscanresult()
	if hs.vulnstatus == 'Vulnerable' then
		--print('Alerts.')
		if hs.vulncount == 1 then
			print('1 alert')
		else
			print(hs.vulncount..' alerts')
		end
	  runtabcmd('seticon','@ICON_CHECKED_RED')
      runtabcmd('runtbtis','MarkAsVulnerable();')
	  printfailure(task.status)
	end
	if hs.vulnstatus == 'Undetermined' then	
	  runtabcmd('seticon','@ICON_CHECKED')
      runtabcmd('runtbtis','MarkAsDone();')
	  printsuccess(task.status)	
	end
	if hs.vulnstatus == 'Secure' then
      print('Secure.')
	  runtabcmd('seticon','@ICON_CHECKED')
      runtabcmd('runtbtis','MarkAsSecure();')
	  printsuccess(task.status)
	end
	if hs.aborted == true then
        print('Fatal Error.')
	    runtabcmd('seticon','@ICON_STOP')
	    if hs.vulnerable == false then
          runtabcmd('runtbtis','MarkAsUndetermined();')
        end
	    printfatalerror(hs.errorreason)
	end
end

function requestdone(r)
  -- add requests during monitoring stage
  if r.isseccheck == false then
    local s = r.method..' '..r.url
    if r.postdata ~= '' then
      s = s..' ['..r.postdata..' ]'
    end
    outputmsg(s,11) -- Adds to messages listview
  end
end

task.caption = 'Syhunt Breach Task'
task.tag = params.sessionname
task:setscript('ondblclick',"browser.showbottombar('task messages')")
task:setscript('onstop',"SessionManager:setsessionstatus([["..params.sessionname.."]], 'Canceled')")

-- if running in background mode, all runtabcmds will be ignored
if parambool('runinbg',true) == true then
  print('Running scan task in background...')
  runtabcmd = function(cmd,value) end
end

runtabcmd('seticon','@ICON_LOADING')
runtabcmd('runtbtis','MarkAsScanning();')
runtabcmd('syncwithtask','1')

print('Scanning for leaks related to domain: '..params.icyurl..'...')
print('Hunt Method: '..params.huntmethod..'...')
print('Session Name: '..params.sessionname)

hs = symini.breach:new()
hs.debug = true
hs.monitor = params.monitor
hs.onlogmessage = log
hs.onthreatfound = addthreat
hs.onprogressupdate = updateprogress
hs.onmapupdate = sitemapupdate
hs.onstatsupdate = statsupdate
hs.onrequestdone = requestdone
hs.ontimelimitreached = printscanresult
hs:start()
hs.huntmethod = params.huntmethod
hs.sessionname = params.sessionname
hs:scandomain(params.icyurl)
task.status = 'Done.'
printscanresult()

if hs.warnings ~= '' then
  runcmd('showmsg',hs.warnings)
end

hs:release()
