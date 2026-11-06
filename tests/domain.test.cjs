/* Finance-domain regression tests; requires the TypeScript compiler from devDependencies. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const ts = require('typescript');
const sourcePath = path.join(__dirname,'../src/model/finance.ts');
const source = fs.readFileSync(sourcePath,'utf8');
const output = ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
const mod={exports:{}};
new Function('module','exports',output)(mod,mod.exports);
const {sumWealth,fmtUGX,parseUGX,valuationAgeDays}=mod.exports;
const assets=[
 {kind:'property',grossValue:200000000,ownerShare:0.5},
 {kind:'investment',grossValue:90000000,ownerShare:1},
 {kind:'savings',grossValue:12000000,ownerShare:1},
];
const debts=[{amount:30000000,linkedAssetId:'property'}];
const a=sumWealth(assets,debts);
assert.equal(a.properties,100000000,'property ownership share');
assert.equal(a.grossAssets,202000000,'gross assets');
assert.equal(a.debts,30000000,'mortgage counted once');
assert.equal(a.netWorth,172000000,'net worth');
assert.equal(a.totalLiquid,12000000,'savings-only liquidity proxy');
assert.equal(sumWealth([],[]).netWorth,0,'empty portfolio');
assert.equal(sumWealth([{kind:'property',grossValue:100,ownerShare:NaN}],[]).grossAssets,0,'invalid ownership ignored');
assert.equal(sumWealth([{kind:'other',grossValue:-10,ownerShare:1}],[]).grossAssets,0,'invalid negative assets ignored');
assert.equal(parseUGX('1,250,000'),1250000,'grouped amount');
assert.equal(parseUGX('-1'),null,'negative invalid for form');
assert.equal(parseUGX('hello'),null,'non numeric invalid');
assert.equal(fmtUGX(-25000),'−UGX 25,000','signed amount display');
assert.equal(valuationAgeDays('2026-01-01',new Date('2026-01-11T00:00:00Z')),10,'valuation age');
console.log('PASS: 12 finance-domain assertions');
