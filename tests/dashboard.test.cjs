const fs=require('fs'), vm=require('vm'), path=require('path'), assert=require('assert');
const base=path.join(__dirname,'../ui/static');
const js=fs.readFileSync(path.join(base,'app.js'),'utf8').replace(/boot\(\);\s*$/, '');
const ctx=vm.createContext({navigator:{language:'de'},localStorage:{getItem:()=>null},document:{documentElement:{dataset:{}},addEventListener(){}},window:{addEventListener(){}},URLSearchParams,Date,Set,console});
vm.runInContext(js,ctx);
vm.runInContext(`
S.lang='de'; S.theme='dark'; S.session={user:'admin@pam',write:true,node:'pve',version:'2.2.1'};
S.inv={self:'pve',version:'2.2.1',nodes:[{name:'pve',online:true,ip:'192.0.2.10'}],guests:[{id:100,name:'pve-autoupdate-ui',type:'lxc'},{id:101,name:'database',type:'lxc'}],config:{NOTIFY:'errors'},last:{'NODE:pve':{update:{ts:100,status:'WARN',summary:'Paketquellen-Fehler: Enterprise-Repo ohne Abo'}},'LXC:100':{update:{ts:200,status:'OK',summary:'5 Pakete aktualisiert'}},'LXC:101':{update:{ts:100,status:'FAIL',summary:'Dienst nach dem Update nicht erreichbar'}}}};
S.history=[{id:'20261105-213800',start:1793911080,mode:'live',status:'ok',packages:5,systems:[{kind:'CT',id:100,node:'pve',name:'pve-autoupdate-ui',status:'OK',summary:'5 Pakete aktualisiert'}]},{id:'20261105-220000',mode:'dryrun',status:'ok',systems:[{name:'CHECK ONLY',status:'TEST'}]}];
`,ctx);
const html=vm.runInContext('renderApp()',ctx);
assert(html.includes('Letzter abgeschlossener Update-Lauf'));
assert(!html.includes('CHECK ONLY'));
assert(html.includes('Paketquellen-Fehler'));
assert(html.includes('Dienst nach dem Update nicht erreichbar'));
assert.equal(vm.runInContext('fleetResults().filter(s=>s.state==="bad").length',ctx),2);
assert(!html.includes('Keine Probleme in den letzten'));
assert(html.includes('Nur Systeme aus diesem Lauf'));
for(const tab of ['guests','history','settings']) { vm.runInContext('S.tab='+JSON.stringify(tab),ctx); assert(vm.runInContext('renderApp()',ctx).includes('sidebar')); }
vm.runInContext("S.tab='overview'; S.history=[]",ctx); assert(vm.runInContext('renderApp()',ctx).includes('fleet-summary'));
vm.runInContext("S.inv.last={}",ctx); assert(vm.runInContext('fleetSummary()',ctx).includes('noch nicht'));
vm.runInContext("S.inv.last={'NODE:pve':{update:{ts:1,status:'OK'}},'LXC:100':{update:{ts:1,status:'OK'}},'LXC:101':{update:{ts:1,status:'OK'}}}",ctx);
assert(vm.runInContext('fleetAttention()',ctx).includes('Keine Probleme'));
vm.runInContext("S.lang='en'",ctx);
assert(vm.runInContext('fleetSummary()',ctx).includes('Checked systems are healthy'));

console.log('Dashboard regression checks passed');


