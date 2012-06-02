var require = function (file, cwd) {
    var resolved = require.resolve(file, cwd || '/');
    var mod = require.modules[resolved];
    if (!mod) throw new Error(
        'Failed to resolve module ' + file + ', tried ' + resolved
    );
    var res = mod._cached ? mod._cached : mod();
    return res;
}

require.paths = [];
require.modules = {};
require.extensions = [".js",".coffee"];

require._core = {
    'assert': true,
    'events': true,
    'fs': true,
    'path': true,
    'vm': true
};

require.resolve = (function () {
    return function (x, cwd) {
        if (!cwd) cwd = '/';
        
        if (require._core[x]) return x;
        var path = require.modules.path();
        cwd = path.resolve('/', cwd);
        var y = cwd || '/';
        
        if (x.match(/^(?:\.\.?\/|\/)/)) {
            var m = loadAsFileSync(path.resolve(y, x))
                || loadAsDirectorySync(path.resolve(y, x));
            if (m) return m;
        }
        
        var n = loadNodeModulesSync(x, y);
        if (n) return n;
        
        throw new Error("Cannot find module '" + x + "'");
        
        function loadAsFileSync (x) {
            if (require.modules[x]) {
                return x;
            }
            
            for (var i = 0; i < require.extensions.length; i++) {
                var ext = require.extensions[i];
                if (require.modules[x + ext]) return x + ext;
            }
        }
        
        function loadAsDirectorySync (x) {
            x = x.replace(/\/+$/, '');
            var pkgfile = x + '/package.json';
            if (require.modules[pkgfile]) {
                var pkg = require.modules[pkgfile]();
                var b = pkg.browserify;
                if (typeof b === 'object' && b.main) {
                    var m = loadAsFileSync(path.resolve(x, b.main));
                    if (m) return m;
                }
                else if (typeof b === 'string') {
                    var m = loadAsFileSync(path.resolve(x, b));
                    if (m) return m;
                }
                else if (pkg.main) {
                    var m = loadAsFileSync(path.resolve(x, pkg.main));
                    if (m) return m;
                }
            }
            
            return loadAsFileSync(x + '/index');
        }
        
        function loadNodeModulesSync (x, start) {
            var dirs = nodeModulesPathsSync(start);
            for (var i = 0; i < dirs.length; i++) {
                var dir = dirs[i];
                var m = loadAsFileSync(dir + '/' + x);
                if (m) return m;
                var n = loadAsDirectorySync(dir + '/' + x);
                if (n) return n;
            }
            
            var m = loadAsFileSync(x);
            if (m) return m;
        }
        
        function nodeModulesPathsSync (start) {
            var parts;
            if (start === '/') parts = [ '' ];
            else parts = path.normalize(start).split('/');
            
            var dirs = [];
            for (var i = parts.length - 1; i >= 0; i--) {
                if (parts[i] === 'node_modules') continue;
                var dir = parts.slice(0, i + 1).join('/') + '/node_modules';
                dirs.push(dir);
            }
            
            return dirs;
        }
    };
})();

require.alias = function (from, to) {
    var path = require.modules.path();
    var res = null;
    try {
        res = require.resolve(from + '/package.json', '/');
    }
    catch (err) {
        res = require.resolve(from, '/');
    }
    var basedir = path.dirname(res);
    
    var keys = (Object.keys || function (obj) {
        var res = [];
        for (var key in obj) res.push(key)
        return res;
    })(require.modules);
    
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        if (key.slice(0, basedir.length + 1) === basedir + '/') {
            var f = key.slice(basedir.length);
            require.modules[to + f] = require.modules[basedir + f];
        }
        else if (key === basedir) {
            require.modules[to] = require.modules[basedir];
        }
    }
};

require.define = function (filename, fn) {
    var dirname = require._core[filename]
        ? ''
        : require.modules.path().dirname(filename)
    ;
    
    var require_ = function (file) {
        return require(file, dirname)
    };
    require_.resolve = function (name) {
        return require.resolve(name, dirname);
    };
    require_.modules = require.modules;
    require_.define = require.define;
    var module_ = { exports : {} };
    
    require.modules[filename] = function () {
        require.modules[filename]._cached = module_.exports;
        fn.call(
            module_.exports,
            require_,
            module_,
            module_.exports,
            dirname,
            filename
        );
        require.modules[filename]._cached = module_.exports;
        return module_.exports;
    };
};

if (typeof process === 'undefined') process = {};

if (!process.nextTick) process.nextTick = (function () {
    var queue = [];
    var canPost = typeof window !== 'undefined'
        && window.postMessage && window.addEventListener
    ;
    
    if (canPost) {
        window.addEventListener('message', function (ev) {
            if (ev.source === window && ev.data === 'browserify-tick') {
                ev.stopPropagation();
                if (queue.length > 0) {
                    var fn = queue.shift();
                    fn();
                }
            }
        }, true);
    }
    
    return function (fn) {
        if (canPost) {
            queue.push(fn);
            window.postMessage('browserify-tick', '*');
        }
        else setTimeout(fn, 0);
    };
})();

if (!process.title) process.title = 'browser';

if (!process.binding) process.binding = function (name) {
    if (name === 'evals') return require('vm')
    else throw new Error('No such module')
};

if (!process.cwd) process.cwd = function () { return '.' };

if (!process.env) process.env = {};
if (!process.argv) process.argv = [];

require.define("path", function (require, module, exports, __dirname, __filename) {
function filter (xs, fn) {
    var res = [];
    for (var i = 0; i < xs.length; i++) {
        if (fn(xs[i], i, xs)) res.push(xs[i]);
    }
    return res;
}

// resolves . and .. elements in a path array with directory names there
// must be no slashes, empty elements, or device names (c:\) in the array
// (so also no leading and trailing slashes - it does not distinguish
// relative and absolute paths)
function normalizeArray(parts, allowAboveRoot) {
  // if the path tries to go above the root, `up` ends up > 0
  var up = 0;
  for (var i = parts.length; i >= 0; i--) {
    var last = parts[i];
    if (last == '.') {
      parts.splice(i, 1);
    } else if (last === '..') {
      parts.splice(i, 1);
      up++;
    } else if (up) {
      parts.splice(i, 1);
      up--;
    }
  }

  // if the path is allowed to go above the root, restore leading ..s
  if (allowAboveRoot) {
    for (; up--; up) {
      parts.unshift('..');
    }
  }

  return parts;
}

// Regex to split a filename into [*, dir, basename, ext]
// posix version
var splitPathRe = /^(.+\/(?!$)|\/)?((?:.+?)?(\.[^.]*)?)$/;

// path.resolve([from ...], to)
// posix version
exports.resolve = function() {
var resolvedPath = '',
    resolvedAbsolute = false;

for (var i = arguments.length; i >= -1 && !resolvedAbsolute; i--) {
  var path = (i >= 0)
      ? arguments[i]
      : process.cwd();

  // Skip empty and invalid entries
  if (typeof path !== 'string' || !path) {
    continue;
  }

  resolvedPath = path + '/' + resolvedPath;
  resolvedAbsolute = path.charAt(0) === '/';
}

// At this point the path should be resolved to a full absolute path, but
// handle relative paths to be safe (might happen when process.cwd() fails)

// Normalize the path
resolvedPath = normalizeArray(filter(resolvedPath.split('/'), function(p) {
    return !!p;
  }), !resolvedAbsolute).join('/');

  return ((resolvedAbsolute ? '/' : '') + resolvedPath) || '.';
};

// path.normalize(path)
// posix version
exports.normalize = function(path) {
var isAbsolute = path.charAt(0) === '/',
    trailingSlash = path.slice(-1) === '/';

// Normalize the path
path = normalizeArray(filter(path.split('/'), function(p) {
    return !!p;
  }), !isAbsolute).join('/');

  if (!path && !isAbsolute) {
    path = '.';
  }
  if (path && trailingSlash) {
    path += '/';
  }
  
  return (isAbsolute ? '/' : '') + path;
};


// posix version
exports.join = function() {
  var paths = Array.prototype.slice.call(arguments, 0);
  return exports.normalize(filter(paths, function(p, index) {
    return p && typeof p === 'string';
  }).join('/'));
};


exports.dirname = function(path) {
  var dir = splitPathRe.exec(path)[1] || '';
  var isWindows = false;
  if (!dir) {
    // No dirname
    return '.';
  } else if (dir.length === 1 ||
      (isWindows && dir.length <= 3 && dir.charAt(1) === ':')) {
    // It is just a slash or a drive letter with a slash
    return dir;
  } else {
    // It is a full dirname, strip trailing slash
    return dir.substring(0, dir.length - 1);
  }
};


exports.basename = function(path, ext) {
  var f = splitPathRe.exec(path)[2] || '';
  // TODO: make this comparison case-insensitive on windows?
  if (ext && f.substr(-1 * ext.length) === ext) {
    f = f.substr(0, f.length - ext.length);
  }
  return f;
};


exports.extname = function(path) {
  return splitPathRe.exec(path)[3] || '';
};

});

require.define("/utility.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var dateStr, emptyStr, isSameDate, isToday, now, nowStr, timeStr, todayStr;

  now = function() {
    return new Date().getTime();
  };

  nowStr = function() {
    return timeStr(now());
  };

  todayStr = function() {
    return new Date().toDateString();
  };

  dateStr = function(time) {
    return new Date(time).toDateString();
  };

  timeStr = function(time) {
    var d, h, m, mer, s;
    d = new Date(time);
    h = d.getHours();
    m = d.getMinutes();
    s = d.getSeconds();
    mer = 'AM';
    if (h > 11) {
      h %= 12;
      mer = 'PM';
    }
    if (h === 0) {
      h = 12;
    }
    if (m < 10) {
      m = '0' + m;
    }
    if (s < 10) {
      s = '0' + s;
    }
    return "" + h + ":" + m + ":" + s + " " + mer;
  };

  isToday = function(time) {
    var predicate, today;
    today = new Date().toDateString();
    predicate = new Date(time).toDateString();
    return today === predicate;
  };

  isSameDate = function(time1, time2) {
    var date1, date2;
    date1 = new Date(time1).toDateString();
    date2 = new Date(time2).toDateString();
    return date1 === date2;
  };

  emptyStr = '';

  module.exports = {
    now: now,
    nowStr: nowStr,
    todayStr: todayStr,
    dateStr: dateStr,
    timeStr: timeStr,
    isToday: isToday,
    isSameDate: isSameDate,
    emptyStr: emptyStr
  };

}).call(this);

});

require.define("/view.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var broadcasts, broadcastsPast, createBroadcast, login, loginFailed, newInput, online, onlineCount, str, textArea, userOffline, userOnline, utility;

  utility = require('./utility');

  str = '';

  onlineCount = 0;

  online = function(users) {
    var user, _i, _len;
    str = " <div class=\"accordion-heading\">\n  <a class=\"accordion-toggle\" data-toggle=\"collapse\" data-parent=\"#broadcast-online\" href=\"#broadcast-users\">\n    <strong>Online</strong> ( <span id=\"online\">" + (onlineCount = users.length) + "</span> )\n  </a>\n</div>\n<div id=\"broadcast-users\" class=\"accordion-body collapse in\">";
    for (_i = 0, _len = users.length; _i < _len; _i++) {
      user = users[_i];
      str += "   <div data-uid=" + user.uid + " class=\"accordion-inner\">\n  <strong>" + (user.name || utility.emptyStr) + "</strong>\n  <span class=\"broadcast-email\">" + (user.email || utility.emptyStr) + "</span>\n</div>";
    }
    str += " </div>";
    return $('#broadcast-online-tmpl').html(str);
  };

  userOnline = function(user) {
    str = "   <div data-uid=" + user.uid + " class=\"accordion-inner\">\n  <strong>" + (user.name || utility.emptyStr) + "</strong>\n  <span class=\"broadcast-email\">" + (user.email || utility.emptyStr) + "</span>\n</div>";
    $('#broadcast-users').prepend(str);
    return $('#online').html(++onlineCount);
  };

  userOffline = function(user) {
    $("div[data-uid=\"" + user.uid + "\"]").remove();
    return $('#online').html(--onlineCount);
  };

  newInput = function() {
    str = " <div id=\"input-active\"></div>\n<div id=\"broadcast-input\" class=\"accordion-inner\">\n  <textarea id=\"broadcast-text-area\" class=\"broadcast-text-area\" rows=\"2\"></textarea>\n</div>\n<div id=\"input-inactive\"></div>";
    return $('#broadcast-today').prepend(str);
  };

  broadcasts = function(log, users) {
    var l;
    str = "<div class=\"accordion-group\">\n<div class=\"accordion-heading\">\n  <a class=\"accordion-toggle\" data-toggle=\"collapse\" data-parent=\"#broadcasts\" href=\"#broadcast-today\">\n    <strong>" + (utility.todayStr()) + "</strong>\n  </a>\n</div>\n<div id=\"broadcast-today\" class=\"accordion-body collapse in\">\n  <div id=\"input-active\"></div>\n  <div id=\"broadcast-input\" class=\"accordion-inner\">\n    <textarea id=\"broadcast-text-area\" class=\"broadcast-text-area\" rows=\"2\"></textarea>\n  </div>\n  <div id=\"input-inactive\"></div>";
    while (l = log != null ? log.pop() : void 0) {
      if (utility.isToday(l.time)) {
        str += "    <div class=\"accordion-inner\">\n  <strong>" + (users[l.uid].name || users[l.uid].email) + "</strong>\n  <span class=\"broadcast-time\">" + (utility.timeStr(l.time)) + "</span>\n  <br/>\n  " + l.text + "\n</div>";
      } else {
        str += "  </div>\n</div>";
        broadcastsPast(log, l, users);
      }
    }
    return $('#broadcasts').html(str);
  };

  broadcastsPast = function(log, l, users) {
    var next;
    str += "<div class=\"accordion-group\">\n<div class=\"accordion-heading\">\n  <a class=\"accordion-toggle\" data-toggle=\"collapse\" data-parent=\"#broadcasts\" href=\"#" + l.time + "\">\n    <strong>" + (utility.dateStr(l.time)) + "</strong>\n  </a>\n</div>\n<div id=\"" + l.time + "\" class=\"accordion-body collapse\">\n  <div class=\"accordion-inner\">\n    <strong>" + (users[l.uid].name || users[l.uid].email) + "</strong>\n    <span class=\"broadcast-time\">" + (utility.timeStr(l.time)) + "</span>\n    <br/>\n    " + l.text + "\n  </div>";
    while (next = log != null ? log.pop() : void 0) {
      if (utility.isSameDate(l.time, next.time)) {
        str += "    <div class=\"accordion-inner\">\n  <strong>" + (users[next.uid].name || users[next.uid].email) + "</strong>\n  <span class=\"broadcast-time\">" + (utility.timeStr(next.time)) + "</span>\n  <br/>\n  " + next.text + "\n</div>";
      } else {
        str += "  </div>\n</div>";
        broadcastsPast(log, next, users);
      }
    }
    return null;
  };

  login = function() {
    str = " <form class=\"form-horizontal\">\n  <div class=\"control-group\">\n    <label class=\"control-label\" for=\"broadcast-name\">Who are you? </label>\n    <div class=\"controls\">\n      <input id=\"broadcast-name\" type=\"text\">\n    </div>\n  </div>\n  <div class=\"control-group\">\n    <label class=\"control-label\" for=\"broadcast-email\">Email <i>(optional)</i></label>\n    <div class=\"controls\">\n      <input id=\"broadcast-email\" type=\"text\">\n    </div>\n  </div>\n</form>";
    return $('#broadcast-input').html(str);
  };

  loginFailed = function() {
    str = " <form class=\"form-horizontal\">\n  <div class=\"alert alert-error fade in\">\n    <button class=\"close\" data-dismiss=\"alert\">&times;</button>\n    <strong>Login Failed:</strong><br/>You must enter your name and / or email.\n  </div>\n  <div class=\"control-group error\">\n    <label class=\"control-label\" for=\"broadcast-name\">Who are you? </label>\n    <div class=\"controls\">\n      <input id=\"broadcast-name\" type=\"text\">\n    </div>\n  </div>\n  <div class=\"control-group error\">\n    <label class=\"control-label\" for=\"broadcast-email\">Email <i>(optional)</i></label>\n    <div class=\"controls\">\n      <input id=\"broadcast-email\" type=\"text\">\n    </div>\n  </div>\n</form>";
    return $('#broadcast-input').html(str);
  };

  textArea = function() {
    str = "<textarea id=\"broadcast-text-area\" class=\"broadcast-text-area\" rows=\"2\"></textarea>";
    return $('#broadcast-input').html(str);
  };

  createBroadcast = function(prependDiv, user, broadcast) {
    str = " <div id=\"b" + broadcast.uid + "\" class=\"accordion-inner\">\n  <strong>" + (user.name || user.email) + "</strong>\n  <span id=\"btime" + broadcast.uid + "\"class=\"broadcast-time\">" + (utility.timeStr(broadcast.time)) + "</span>\n  <br/>\n  <span id=\"btext" + broadcast.uid + "\"class=\"broadcast-text glow\">" + broadcast.text + "</span>\n</div>";
    $('#' + prependDiv).prepend(str);
    return $('#btext' + broadcast.uid).removeClass('glow', 1000);
  };

  module.exports = {
    online: online,
    userOnline: userOnline,
    userOffline: userOffline,
    broadcasts: broadcasts,
    login: login,
    loginFailed: loginFailed,
    textArea: textArea,
    createBroadcast: createBroadcast,
    newInput: newInput
  };

}).call(this);

});

require.define("/controller.coffee", function (require, module, exports, __dirname, __filename) {
    (function() {
  var alreadyOn, broadcastEnter, broadcastKeyup, chartData, determineActiveUsers, freshTextArea, getSelectionPos, glow, glowId, imHere, intervalId, listen, live, loginFormEventHandler, model, socket, textAreaActive, textAreaEventHandler, url, utility, view;

  utility = require('./utility');

  view = require('./view');

  url = 'http://localhost:1986';

  socket = {};

  model = {};

  textAreaActive = false;

  $.getScript("" + url + "/lib/bootstrap/js/bootstrap-collapse.js");

  $.getScript("" + url + "/lib/jquery-ui-1.8.20.custom.min.js");

  $.getScript("" + url + "/socket.io/socket.io.js", function() {
    return $.getJSON("" + url + "/data", function(data) {
      model = data;
      view.online(determineActiveUsers());
      view.broadcasts(data.log, data.users);
      return live();
    });
  });

  live = function() {
    socket = io.connect(url);
    socket.emit('client-test', "hi: " + (utility.timeStr(utility.now())));
    if ((model != null ? model.iam : void 0) != null) {
      imHere(true);
    }
    listen();
    return $('#broadcast-text-area').bind('keyup click', textAreaEventHandler);
  };

  chartData = {
    e: {
      words: [],
      count: 0
    },
    i: {
      words: [],
      count: 0
    },
    d: {
      words: [],
      count: 0
    },
    s: {
      words: [],
      count: 0
    },
    a: {
      words: [],
      count: 0
    },
    p: {
      words: [],
      count: 0
    },
    u: {
      words: [],
      count: 0
    }
  };

  listen = function() {
    socket.on('server-test', function(data) {
      return console.log('server-test: ' + data);
    });
    socket.on('emoo', function(data) {
      var pollData, word, _i, _len, _ref;
      pollData = JSON.parse(data);
      console.log(['emoo: ', pollData]);
      chartData = {
        e: {
          words: [],
          count: 0
        },
        i: {
          words: [],
          count: 0
        },
        d: {
          words: [],
          count: 0
        },
        s: {
          words: [],
          count: 0
        },
        a: {
          words: [],
          count: 0
        },
        p: {
          words: [],
          count: 0
        },
        u: {
          words: [],
          count: 0
        }
      };
      _ref = pollData.words;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        word = _ref[_i];
        switch (word.type) {
          case 'E':
            chartData.e.count += 1;
            chartData.e.words.push(word.word);
            break;
          case 'I':
            chartData.i.count += 1;
            chartData.i.words.push(word.word);
            break;
          case 'D':
            chartData.d.count += 1;
            chartData.d.words.push(word.word);
            break;
          case 'S':
            chartData.s.count += 1;
            chartData.s.words.push(word.word);
            break;
          case 'A':
            chartData.a.count += 1;
            chartData.a.words.push(word.word);
            break;
          case 'P':
            chartData.p.count += 1;
            chartData.p.words.push(word.word);
            break;
          case 'U':
            chartData.u.count += 1;
            chartData.u.words.push(word.word);
        }
      }
      return console.log(['chartData', chartData]);
    });
    socket.on('needs-login', function(nothing) {
      console.log('needs-login');
      view.login();
      $('#broadcast-name').keyup(loginFormEventHandler);
      return $('#broadcast-email').keyup(loginFormEventHandler);
    });
    socket.on('bad-login', function(nothing) {
      console.log('bad-login');
      return view.loginFailed();
    });
    socket.on('server-keyup', function(broadcast) {
      console.log(['server-keyup', broadcast]);
      return broadcastKeyup(broadcast);
    });
    socket.on('server-enter', function(broadcast) {
      console.log(['server-enter', broadcast]);
      return broadcastEnter(broadcast);
    });
    socket.on('server-delete', function(broadcast) {
      return console.log('todo delete');
    });
    socket.on('iam', function(uid) {
      console.log(['iam', uid]);
      model.iam = uid;
      imHere(true);
      view.textArea();
      freshTextArea();
      return $('#broadcast-text-area').bind('keyup click', textAreaEventHandler);
    });
    socket.on('active', function(uid) {
      var user;
      console.log(['active', uid]);
      user = model.users[uid];
      if (user.active === false) {
        user.active = true;
        return view.userOnline(user);
      }
    });
    socket.on('inactive', function(uid) {
      var user;
      console.log(['inactive', uid]);
      user = model.users[uid];
      user.active = false;
      return view.userOffline(user);
    });
    return socket.on('new-user', function(user) {
      console.log(['new-user', user]);
      return model.users[user.uid] = user;
    });
  };

  determineActiveUsers = function() {
    var activeUsers, user, _i, _len, _ref;
    activeUsers = [];
    _ref = model.users;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      user = _ref[_i];
      if (user.active === true) {
        activeUsers.push(user);
      }
    }
    return activeUsers.sort(function(a, b) {
      return b.lastActivity - a.lastActivity;
    });
  };

  broadcastKeyup = function(broadcast) {
    var bid;
    bid = 'b' + broadcast.uid;
    if (!document.getElementById(bid)) {
      if (broadcast.uid === model.iam) {
        view.createBroadcast('old', model.users[broadcast.uid], broadcast);
        return $('#old').replaceWith($('#old').children());
      } else if (textAreaActive) {
        return view.createBroadcast('input-active', model.users[broadcast.uid], broadcast);
      } else {
        return view.createBroadcast('input-inactive', model.users[broadcast.uid], broadcast);
      }
    } else {
      return glow(broadcast);
    }
  };

  broadcastEnter = function(broadcast) {
    broadcastKeyup(broadcast);
    return $('#b' + broadcast.uid).removeAttr('id');
  };

  textAreaEventHandler = function(event) {
    var broadcast, text;
    textAreaActive = true;
    text = $('#broadcast-text-area').val();
    broadcast = {
      uid: model.iam,
      text: text,
      pos: getSelectionPos('broadcast-text-area')
    };
    if (event.which === 13) {
      broadcast.text = text.substring(0, text.length - 1);
      freshTextArea();
      return socket.emit('client-enter', broadcast);
    } else {
      return socket.emit('client-keyup', broadcast);
    }
  };

  freshTextArea = function() {
    var input;
    $('#input-active').replaceWith($('#input-active').children());
    $('#input-inactive').attr('id', 'old');
    input = $('#broadcast-input');
    input.prependTo('#broadcast-today');
    input.before("<div id=\"input-active\"></div>");
    input.after("<div id=\"input-inactive\"></div>");
    $('#broadcast-text-area').val('').focus();
    return textAreaActive = false;
  };

  loginFormEventHandler = function(event) {
    var email, name;
    if (event.which === 13) {
      name = $('#broadcast-name').val();
      email = $('#broadcast-email').val();
      if ((name != null ? name.length : void 0) > 0 || (email != null ? email.length : void 0) > 0) {
        socket.emit('login', {
          name: name,
          email: email
        });
      } else {
        view.loginFailed();
      }
      return textAreaActive = false;
    }
  };

  getSelectionPos = function(id) {
    var el, iePos, sel;
    el = document.getElementById(id);
    if (document.selection) {
      el.focus();
      sel = document.selection.createRange();
      sel.moveStart('character', -el.value.length);
      iePos = sel.text.length;
      return {
        start: iePos,
        end: iePos
      };
    } else {
      return {
        start: el.selectionStart,
        end: el.selectionEnd
      };
    }
  };

  glowId = 0;

  glow = function(broadcast) {
    var afterText, beforeText, glowText, html, newCharIdx, selEnd, selStart, text;
    text = broadcast.text;
    selStart = broadcast.pos.start;
    selEnd = broadcast.pos.end;
    newCharIdx = selStart - 1;
    glowText = text.charAt(newCharIdx);
    if (glowText === '\n') {
      return;
    }
    if (selStart === selEnd) {
      beforeText = text.slice(0, newCharIdx);
      afterText = text.slice(selEnd);
    } else {
      beforeText = text.slice(0, selStart);
      glowText = text.slice(selStart, selEnd);
      afterText = text.slice(selEnd);
    }
    html = "" + beforeText + "<span class=\"glow\" id=\"g" + glowId + "\">" + glowText + "</span>" + afterText;
    $('#btime' + broadcast.uid).html(utility.timeStr(broadcast.time));
    $('#btext' + broadcast.uid).html(html);
    $('#g' + glowId).removeClass('glow', 1000);
    return glowId++;
  };

  alreadyOn = false;

  intervalId = 0;

  imHere = function(boolean) {
    if (boolean === true && alreadyOn === false) {
      intervalId = setInterval(function() {
        console.log("I'm here! ( " + model.iam + " )");
        return socket.emit('here', model.iam);
      }, 6543);
      return alreadyOn = true;
    } else {
      clearInterval(intervalId);
      return alreadyOn = false;
    }
  };

}).call(this);

});
require("/controller.coffee");
