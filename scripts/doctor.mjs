import fs from 'fs';
const config=fs.readFileSync(new URL('../www/config.js',import.meta.url),'utf8');
const checks=[];
checks.push(['API configured',!/YOUR-DOMAIN/i.test(config)]);
checks.push(['Logo exists',fs.existsSync(new URL('../www/assets/wara2a-qalam-logo.jpg',import.meta.url))]);
checks.push(['Icon exists',fs.existsSync(new URL('../resources/icon.png',import.meta.url))]);
checks.push(['Splash exists',fs.existsSync(new URL('../resources/splash.png',import.meta.url))]);
for(const [n,ok] of checks) console.log(`${ok?'OK':'WAIT'} - ${n}`);
if(checks.some(x=>!x[1])) process.exitCode=2;
