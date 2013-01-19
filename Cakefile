{spawn, exec} = require 'child_process'

src = ['nimbus.coffee']

task 'watch', 'continually build with --watch', ->
    p1 = spawn 'coffee', ['-wc'].concat src
    p1.stdout.on 'data', (data) -> console.log data.toString().trim()

    p2 = spawn 'coffee', ['-wcbo', 'test'].concat src
    p2.stdout.on 'data', (data) -> console.log data.toString().trim()

    p3 = spawn 'coffee', ['-wc','spec']
    p3.stdout.on 'data', (data) -> console.log data.toString().trim()

task 'worker', 'build coffee-script-worker.js', ->
    exec 'cat csWorker.js ~/Opensources/coffee-script/extras/coffee-script.js > coffee-script-worker.js', (error, stdout, stderr) ->