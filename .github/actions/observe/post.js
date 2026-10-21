const {execFileSync} = require('child_process')
const path = require('path')

execFileSync('bash', [path.join(__dirname, 'stop.sh')], {stdio: 'inherit'})
