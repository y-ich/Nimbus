###
# Controller for dropbox-js
# dependencies: dropbox-js.js, jquery.js, spin.js
# usage:
#  1. prepare view (button for sign-in and sign-out, table for file list)
# (C) 2012-2013 ICHIKAWA, Yuji (New 3 Rs)
###

# global variables

API_KEY = 'YhIlKUggAFA=|prhxrh5PMBEqJAeN5Jjox+gc9NV/zlEy2UGJTcK+4A=='
dropbox = null
config = null
spinner = new Spinner color: '#fff'

# view
$signInout = $('#sign-inout')
$fileTable = $('#main table')
$folderList = $('#footer .breadcrumb')

# general functions

compareString = (str1, str2) ->
    if str1 > str2
        1
    else if str1 < str2
        -1
    else
        0

dateString = (date) -> date.toDateString().replace(/^.*? /, '') + ' ' + date.toTimeString().replace(/GMT.*$/, '')

byteString = (n) ->
    if n < 1000
        n.toString() + 'B'
    else if n < 1000000
        Math.floor(n / 1000).toString() + 'KB'
    else if n < 1000000000
        Math.floor(n / 1000000).toString() + 'MB'
    else if n < 1000000000000
        Math.floor(n / 1000000000).toString() + 'GB'

getExtension = (path) -> if /\./.test path then path.replace /^.*\./, '' else ''

# '/' => ['']
# '/a/b/c' => ['', '/a', '/a/b', '/a/b/c']
ancestorFolders = (path) ->
    return [''] if path is '/'
    split = path.split '/'
    split[0..i].join '/' for e, i in split

handleError = (error) ->
    console.error error if (window.console)
    switch error.status
        when 401
            alert 'Authentication is expired. Please sign-in again.'
            $signInout.button 'reset'
        when 404
            alert 'No such file or folder.'
        when 507
            alert 'Your Dropbox seems full.'
        when 503
            alert 'Dropbox seems busy. Please try again later.'
        when 400
            alert 'Bad input parameter.'
        when 403  
            alert 'Please sign-in at first.'
        when 405
            alert 'Request method not expected.'
        else
            alert 'Sorry, there seems something wrong in software.'


makeFileList = (stats, order, direction) ->
    ITEMS =
        image: (stat) -> "<td><img src=\"images/dropbox-api-icons/48x48/#{stat.typeIcon}48.gif\"></td>"
        name: (stat) -> "<td>#{stat.name}</td>"
        date: (stat) -> "<td>#{dateString stat.modifiedAt}</td>"
        size: (stat) -> "<td style=\"text-align: right;\">#{byteString stat.size}</td>"
        kind: (stat) -> "<td>#{if stat.isFile then getExtension stat.name else 'folder'}</td>"
    if stats?
        $fileTable.data 'dropbox', stats
    else
        stats = $fileTable.data 'dropbox'
    $fileTable.children().remove()
    
    th = (key) -> "<th#{if order is key then " class=\"#{direction}\"" else ''}><span>#{key}</span></th>"
    $fileTable.append "<tr>#{Object.keys(ITEMS).map(th).join('')}</tr>"
            
    sign = if direction is 'ascending' then 1 else -1
    sortFunc = switch order
            when 'name'
                (a, b) -> sign * compareString a.name.toLowerCase(), b.name.toLowerCase()
            when 'kind'
                (a, b) -> sign * compareString getExtension(a.name).toLowerCase(), getExtension(b.name).toLowerCase()
            when 'date'
                (a, b) -> sign * (a.modifiedAt.getTime() - b.modifiedAt.getTime())
            when 'size'
                (a, b) -> sign * (a.size - b.size)        
    stats = stats.sort sortFunc

    for stat in stats
        $tr = $("<tr>#{(value(stat) for key, value of ITEMS).join('')}</tr>")
        $tr.data 'dropbox-stat', stat
        $fileTable.append $tr

showFolder = (path = '/') ->
    spinner.spin document.body
    dropbox.readdir path, null, (error, names, stat, stats) ->
        spinner.stop()
        if error
            handleError error
        else
            updateFolderList path
            makeFileList stats, config.fileList.order, config.fileList.direction
        $fileTable.on 'click', 'tr', onClickFileRow # enable to click.

restoreConfig = ->
    defaultConfig =
        currentFolder: '/'
        fileList:
            order: 'name'
            direction: 'ascending'
    config = JSON.parse localStorage['nimbus-config'] ? '{}'
    for key, value of defaultConfig
        config[key] ?= value

updateFolderList = (path) ->
    $folderList.children().remove()
    for e, i in ancestorFolders path
        if i == 0
            $folderList.append '<li><a href="#" data-path="/">Home</a></li>'
        else
            name = e.replace /^.*\//, ''
            $folderList.append """
                <li>
                    <span class="divider">/</span>
                    <a href="#" data-path="#{e}">#{name}</a>
                </li>
                """
    $folderList.children('li:last-child').addClass 'active'

# 1. prepares Dropbox Client instance.
# 2. checks URL. if it includes not_approved=true, a user rejected authentication request. Does nothing.
# 3. checks localStorage. if it includes data for this APP_KEY, tries to sign in. 
initializeDropbox = ->
    dropbox = new Dropbox.Client
        key: API_KEY
        sandbox: false
    dropbox.authDriver new Dropbox.Drivers.Redirect rememberUser: true
    
    return if /not_approved=true/.test location.toString() # if redirect result shows that a user rejected

    try
        for key, value of localStorage when /^dropbox-auth/.test(key) and JSON.parse(value).key is dropbox.oauth.key
            $signInout.button 'loading'
            dropbox.authenticate (error, client) ->
                if error
                    handleError error 
                    $signInout.button 'reset'
                else
                    $signInout.button 'signout'
                    showFolder config.currentFolder
            break
    catch error
        console.log error

onClickFileRow = ->
        $this =$(this)
        stat = $this.data('dropbox-stat')
        if not stat?
            return
        if stat.isFile
            $fileTable.find('tr').removeClass 'info'
            $this.addClass 'info'
        else if stat.isFolder
            $fileTable.off 'click', 'tr', onClickFileRow # disable during updating.
            showFolder stat.path
            config.currentFolder = stat.path
            localStorage['nimbus-config'] = JSON.stringify config

initializeEventHandlers = ->
    $signInout.on 'click', ->
        $this = $(this)
        if $this.text() is 'sign-in'
            $this.button 'loading'
            dropbox.reset()
            dropbox.authenticate (error, client) ->
                spinner.stop()
                if error then handleError error else $this.button 'signout'
        else
            dropbox.signOut (error) ->
                spinner.stop()
                if error then handleError error else $this.button 'reset'
        spinner.spin document.body

    $folderList.on 'click', 'li:not(.active) > a', ->
        $this = $(this)
        $this.parent().nextUntil().remove()
        $this.parent().addClass 'active'
        path = $this.data 'path'
        showFolder path
        config.currentFolder = path
        localStorage['nimbus-config'] = JSON.stringify config
        false # prevent default
    
    $fileTable.on 'click', 'tr > th:not(:first)', ->
        $this = $(this)
        if $this.hasClass 'ascending'
            config.fileList.direction = 'descending'
        else if $this.hasClass 'descending'
            config.fileList.direction = 'ascending'
        else
            config.fileList.order = $this.children('span').text()
            config.fileList.direction = 'ascending'
        makeFileList null, config.fileList.order, config.fileList.direction

restoreConfig()
initializeDropbox()
initializeEventHandlers()