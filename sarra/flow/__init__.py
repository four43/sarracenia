
import logging
import netifaces
import sarra.plugins
import time
import types

from abc import ABCMeta, abstractmethod

from sarra.sr_util import nowflt

logger = logging.getLogger( __name__ )

class Flow:
    __metaclass__ = ABCMeta
    """
      implement the General Algorithm from the Concepts Guide.
      just pure program logic all the start, status, stop, log & instance management taken care of elsewhere.
      
      need to know whether to sleep between passes  
      o.sleep - an interval (floating point number of seconds)
      o.housekeeping - 
    """
  
    def __init__(self,o=None):

       
       self._stop_requested = False
       # FIXME: set o.sleep, o.housekeeping
       self.o = types.SimpleNamespace()
       self.o.sleep = 10
       self.o.housekeeping = 30

       # FIXME: open cache, get masks. 
       # FIXME: open new_worklist
       # FIXME: initialize retry_list
       # FIXME: initialize vip 
       self.o.vip = None

       # FIXME: open retry
 
       # override? or merge... hmm...
       if o is not None:
           self.o = o

       logger.info('shovel constructor')
       #self.o.dump()
    

    def has_vip(self):
        # no vip given... standalone always has vip.
        if self.o.vip == None:
           return True

        for i in netifaces.interfaces():
            for a in netifaces.ifaddresses(i):
                j=0
                while( j < len(netifaces.ifaddresses(i)[a]) ) :
                    if self.o.vip in netifaces.ifaddresses(i)[a][j].get('addr'):
                       return True
                    j+=1
        return False

    def please_stop(self):
        self._stop_requested = True

    def run(self):

        next_housekeeping=nowflt()+self.o.housekeeping

        if self.o.sleep > 0:
            last_time = nowflt()
       
        while True:

           if self._stop_requested:
               self.close()
               break

           if self.has_vip():
               worklist = self.gather()
               self.filter()
               self.do()
               self.post()
               self.report()
         
           now = nowflt()
           if now > next_housekeeping:
               logger.info('on_housekeeping')
               next_housekeeping=now+self.o.housekeeping

           if self.o.sleep > 0:
               elapsed = now - last_time
               if elapsed < self.o.sleep:
                   stime=self.o.sleep-elapsed
                   if stime > 60:  # if sleeping for a long time, debug output is good...
                       logger.debug("sleeping for more than 60 seconds: %g seconds. Elapsed since wakeup: %g Sleep setting: %g " % ( stime, elapsed, self.o.sleep ) )
               time.sleep(stime)
               last_time = now

    def filter(self):
        # apply cache, reject.
        # apply masks, reject.
        logger.info('self.o.bindings %s' % self.o.bindings )
        # apply on_message plugins.
        logger.info('filter - unimplemented')

    @abstractmethod
    def gather(self):
        logger.info('gather - unimplemented')
 
    @abstractmethod 
    def do( self ):
        logger.info('do - unimplemented')
  
    @abstractmethod 
    def post( self ):
        # post messages
        # apply on_post plugins
        logger.info('post - unimplemented')
   
    @abstractmethod 
    def report( self ):
        # post reports
        # apply on_report plugins
        logger.info('report -unimplemented')

    @abstractmethod 
    def close( self ):
        logger.info('closing')
