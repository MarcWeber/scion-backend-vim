import sys, tokenize, cStringIO, types, socket, string, os, re, time
import threading
from subprocess import Popen, PIPE, STDOUT

# environement, fake if run manually {{{1
try:

  # run by vim
  import vim

  is_vim = True
  TEMP_NAME = vim.eval("tempname()")


  # TODO use vimQuote everywhere
  def vimQuote(s):
    return '"%s"' % s.replace("\\","\\\\").replace('"', '\\"').replace("\n", "\\n")

  def debug(s):
    vim.command("echom %s" % vimQuote(s))

  # def ask_user(question):
    # return vim.eval("input('%s')" % question)

  def vimSet(var,val):
    vim.command("let %s=%s" % (var, vimQuote(val)))

except ImportError, e:

  # run manually, fake some vim stuff

  is_vim = False
  DEBUG = True
  TEMP_NAME = "/tmp/file"
  print "tempfile is ", TEMP_NAME

  def debug(s):
    print "debug: ", s

  # def ask_user(question):
  #   print "ABC"
  #   print question
  #   return raw_input()

  def vimSet(var,val):
    print "setting %s to %s" % (var,val)

# START IMPORTANT CODE {{{1


# if server object exists shutdown
# user must reconnect. If this file is executed code has cahnged
if 'scion_server' in globals():
  scion_server.shutdown()


class ScionThreadLogToFile ( threading.Thread ):
  def __init__(self, file, stdout):
    threading.Thread.__init__(self)
    self.file = open(file, 'w')
    self.stdout = stdout

  def run (self):
    # don't try to callback into vim within this thread
    # it would crash Vim!
    while True:
      s = self.stdout.readline()
      if s != "":
        self.file.write(s)
        self.file.write("\n")
        self.file.flush()
      time.sleep(1)

class ScionServer:
  def __init__(self, scionserver_path, scion_server_log_prefix):
    self.scionserver_path = scionserver_path
    self.scion_server_log_prefix = scion_server_log_prefix
    self.process = False

  def start(self):
    # 1) start server
    # p = Popen([self.scionserver_path"-i","-f", "%s/scion-log-%s"%(vim.eval("g:scion_tmp_dir"), os.getcwd().replace('/','_').replace('\\','_'))], \
    debug("py: starting scion server %s" % self.scionserver_path)
    p = Popen([self.scionserver_path,'-json'], \
            shell = False, bufsize = 1, stdin = PIPE, stdout = PIPE, stderr = STDOUT)
    self.scion_o = p.stdout
    self.scion_i = p.stdin
    self.scion_err = p.stderr

    self.process = p

    # 2) read port from stdout
    # first line should be 
    # === Listening on port: 4040
    # or such
    l = self.scion_o.readline()
    match = re.match("=== Listening on port: ([0123456789]+)", l)
    if match == None:
      raise Exception("bad, line which should contain the port didn't match regex: %s" % l)
    port = int(match.group(1))
    print ("scion is running on port %d" % port)

    # 3) now start logging things in separate thread
    self.server_logfile_path = "%s-%d" % (self.scion_server_log_prefix, port)
    print "logging to %s" % self.server_logfile_path
    self.logging_thread = ScionThreadLogToFile(self.server_logfile_path, self.scion_o)
    self.logging_thread.start()

    # 4) start listening on port
    connection = ('127.0.0.1', port)
    su = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    su.settimeout(20)
    su.connect(connection)
    # making file to use readline()
    self.socket_file = su.makefile('rw')

  def shutdown(self):
    debug("py: shutting down scion server")

    self.socket_file.write("[{\"Nothing\":null},{\"QuitServer\":[]}])\n")
    self.socket_file.flush()

    if self.process != False:
      self.process.kill()
      self.process.wait()
    # TODO: this will close stdout thus cause error in thread which should stop then. This cane be done more gracefully

  def send_receive(self, s):
    # only sends / receives lines. Rest should be done in VimL
    self.socket_file.write(s)
    self.socket_file.write("\n")
    self.socket_file.flush()
    vimSet('scion_result_str', self.socket_file.readline()[:-1])

def scion_reconnect(mode):
  global scion_server
  if mode in ["disconnect","reconnect"] and "scion_server" in globals():
    scion_server.shutdown()
    del scion_server

  if mode in ["reconnect","connect"] and not ("scion_server" in globals()):
    scion_server = ScionServer(vim.eval('g:scion_config.scion_server_path'), TEMP_NAME)
    scion_server.start()


# END IMPORTANT CODE }}}

if not is_vim:
  # again for testing:
  scion_server = ScionServer('/pr/haskell/scion/dist/build/scion-server/scion-server', TEMP_NAME)
  scion_server.start()
  while True:
    print "send json:"
    s = raw_input()
    if s == 'exit':
      import sys
      sys.exit()
    scion_server.send_receive(s)

# vim:sw=2 fdm=marker
