import socket
import time
import xmlrpclib

import supervisor.xmlrpc

from checks import AgentCheck


DEFAULT_HOST = 'localhost'
DEFAULT_PORT = '9001'
DEFAULT_SERVER = 'server'
DEFAULT_SOCKET_IP = 'http://127.0.0.1'

OK = AgentCheck.OK
CRITICAL = AgentCheck.CRITICAL
UNKNOWN = AgentCheck.UNKNOWN

DD_STATUS = {
    'STOPPED': CRITICAL,
    'STARTING': OK,
    'RUNNING': OK,
    'BACKOFF': UNKNOWN,
    'STOPPING': CRITICAL,
    'EXITED': CRITICAL,
    'FATAL': CRITICAL,
    'UNKNOWN': UNKNOWN
}

PROCESS_STATUS = {
    CRITICAL: 'down',
    OK: 'up',
    UNKNOWN: 'unknown'
}

FORMAT_TIME = lambda x: time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(x))


class SupervisordCheck(AgentCheck):

    def check(self, instance):
        server_name = instance.get('name', DEFAULT_SERVER)
        supervisor = self._connect(instance)
        count_by_status = {
            AgentCheck.OK: 0,
            AgentCheck.CRITICAL: 0,
            AgentCheck.UNKNOWN: 0
        }

        # Grab process information
        try:
            proc_names = instance.get('proc_names')
            if proc_names and len(proc_names):
                processes = []
                for proc_name in proc_names:
                    try:
                        processes.append(supervisor.getProcessInfo(proc_name))
                    except xmlrpclib.Fault, e:
                        if e.faultCode == 10:
                            self.log.warn('Process not found: %s' % proc_name)
                        else:
                            raise Exception('An error occurred while reading'
                                            'process %s information: %s %s'
                                            % (proc_name, e.faultCode, e.faultString))
            else:
                processes = supervisor.getAllProcessInfo()
        except socket.error:
            host = instance.get('host', DEFAULT_HOST)
            port = instance.get('port', DEFAULT_PORT)
            raise Exception('Cannot connect to http://%s:%s.\n'
                            'Make sure supervisor is running and XML-RPC '
                            'inet interface is enabled.' % (host, port))
        except xmlrpclib.ProtocolError, e:
            instance_name = instance.get('name')
            if e.errcode == 401:
                raise Exception('Username or password to %s are incorrect.' %
                                instance_name)
            else:
                raise Exception('An error occurred while connecting to %s: '
                                '%s %s ' % (instance_name, e.errcode, e.errmsg))

        # Report service checks and uptime for each process
        for proc in processes:
            proc_name = proc['name']
            tags = ['supervisord',
                    'server:%s' % server_name,
                    'process:%s' % proc_name]

            # Report Service Check
            status = DD_STATUS[proc['statename']]
            msg = self._build_message(proc)
            count_by_status[status] += 1
            self.service_check('supervisord.process.check',
                               status, tags=tags, message=msg)
            # Report Uptime
            uptime = self._extract_uptime(proc)
            self.gauge('supervisord.process.uptime', uptime, tags=tags)

        # Report counts by status
        tags = ['supervisord', 'server:%s' % server_name]
        for status in PROCESS_STATUS:
            self.gauge('supervisord.process.count', count_by_status[status],
                       tags=tags + ['status:%s' % PROCESS_STATUS[status]])

    @staticmethod
    def _connect(instance):
        sock = instance.get('socket')
        if sock is not None:
            host = instance.get('host', DEFAULT_SOCKET_IP)
            transport = supervisor.xmlrpc.SupervisorTransport(None, None, sock)
            server = xmlrpclib.ServerProxy(host, transport=transport)
        else:
            host = instance.get('host', DEFAULT_HOST)
            port = instance.get('port', DEFAULT_PORT)
            user = instance.get('user')
            password = instance.get('pass')
            auth = '%s:%s@' % (user, password) if user and password else ''
            server = xmlrpclib.Server('http://%s%s:%s/RPC2' % (auth, host, port))
        return server.supervisor

    @staticmethod
    def _extract_uptime(proc):
        start, stop, now = int(proc['start']), int(proc['stop']), int(proc['now'])
        if proc['statename'] == 'RUNNING' and stop == 0:
            return now - start
        else:
            return 0 if stop >= start else now - start

    @staticmethod
    def _build_message(proc):
        start, stop, now = int(proc['start']), int(proc['stop']), int(proc['now'])
        proc['now_str'] = FORMAT_TIME(now)
        proc['start_str'] = FORMAT_TIME(start)
        proc['stop_str'] = '' if stop == 0 else FORMAT_TIME(stop)

        return """Current time: %(now_str)s
Process name: %(name)s
Process group: %(group)s
Description: %(description)s
Error log file: %(stderr_logfile)s
Stdout log file: %(stdout_logfile)s
Log file: %(logfile)s
State: %(statename)s
Start time: %(start_str)s
Stop time: %(stop_str)s
Exit Status: %(exitstatus)s""" % proc
