#!/usr/bin/python3

"""
 print a message indicating how old messages received are.
 this should be used as an on_part script. For each part received it will print a line
 in the local log that looks like this:

2015-12-23 22:54:30,328 [INFO] posted: 20151224035429.115 (lag: 1.21364 seconds ago) to deliver: /home/peter/test/dd/bulletins/alphanumeric/20151224/SA/EGGY/03/SAUK32_EGGY_240350__EGAA_64042, 

 the number printed after "lag:" the time between the moment the message was originally posted on the server, 
 and the time the script was called, which is very near the end of writing the file to local disk.

 This can be used to gauge whether the number of instances or internet link are sufficient
 to transfer the data selected.  if the lag keeps increasing, then something must be done, either

"""

import os,stat,time

class Transformer(object): 

    import calendar

    def __init__(self,parent):
          pass
          
    def on_message(self,parent):
        logger = parent.logger
        msg    = parent.msg

        import calendar
        from sarra.sr_util import timestr2flt

        then=timestr2flt(msg.pubtime)
        now=time.time()

        logger.info("print_lag, posted: %s, lag: %g sec. to deliver: %s, " % (msg.pubtime, (now-then), msg.new_file))

        return True

transformer = Transformer(self)
self.on_message = transformer.on_message

