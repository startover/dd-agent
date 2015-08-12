import traceback

def shell():
    from config import get_version

    print """
OneAPM Agent v%s - Python Shell

    """ % (get_version())
    while True:
        cmd = raw_input('>>> ')
        try:
            exec(cmd)
        except Exception, e:
            print traceback.format_exc(e)

if __name__ == "__main__":
    shell()
