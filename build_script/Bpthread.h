#include <pthread.h>
#include <signal.h>

#define SIG_CANCEL_SIGNAL SIGUSR1
#define PTHREAD_CANCEL_ENABLE 1
#define PTHREAD_CANCEL_DISABLE 0


static int pthread_setcancelstate(int state, int *oldstate) {
    sigset_t   new, old;
    int ret;
    sigemptyset (&new);
    sigaddset (&new, SIG_CANCEL_SIGNAL);

    ret = pthread_sigmask(state == PTHREAD_CANCEL_ENABLE ? SIG_BLOCK : SIG_UNBLOCK, &new , &old);
    if(oldstate != NULL)
    {
        *oldstate =sigismember(&old,SIG_CANCEL_SIGNAL) == 0 ? PTHREAD_CANCEL_DISABLE : PTHREAD_CANCEL_ENABLE;
    }
    return ret;
}


static inline int pthread_cancel(pthread_t thread) {

    pthread_kill(thread, SIG_CANCEL_SIGNAL);
}
