#!/usr/bin/bash -e
PATCHDIR=${0%/*}

cp -vr $PATCHDIR/rekernel common/drivers/rekernel

sed -i '/endmenu/i\source "drivers/rekernel/Kconfig"' common/drivers/Kconfig

echo 'obj-$(CONFIG_REKERNEL) += rekernel/' >> common/drivers/Makefile

line=$(($(awk '/binder_proc_transaction\(\) - sends a transaction to a process and wakes it up/{print NR}' common/drivers/android/binder.c)-1))
sed -i common/drivers/android/binder.c \
-e '/#include <uapi\/linux\/android\/binder.h>/i\
#ifdef CONFIG_REKERNEL\
#include <../rekernel/rekernel.h>\
#endif /* CONFIG_REKERNEL */' \
-e '/if ((t1->flags & t2->flags & (TF_ONE_WAY | TF_UPDATE_TXN)) !=/i\
#ifdef CONFIG_REKERNEL\
	if ((t1->flags & t2->flags & TF_ONE_WAY) != TF_ONE_WAY || !t1->to_proc || !t2->to_proc)\
#else' \
-e '/(TF_ONE_WAY | TF_UPDATE_TXN) || !t1->to_proc || !t2->to_proc)/a\
#endif /* CONFIG_REKERNEL */' \
-e '/if ((t->flags & TF_UPDATE_TXN) && proc->is_frozen) {/i\
#ifdef CONFIG_REKERNEL\
		if (frozen_task_group(proc->tsk)) {\
#else' \
-e '/if ((t->flags & TF_UPDATE_TXN) && proc->is_frozen) {/a\
#endif /* CONFIG_REKERNEL */' \
-e ''"$line"'i\
#ifdef CONFIG_REKERNEL\
void rekernel_binder_transaction(bool reply, struct binder_transaction *t,\
				 struct binder_node *target_node, struct binder_transaction_data *tr) {\
	struct binder_proc *to_proc;\
	struct binder_alloc *target_alloc;\
	if (!t->to_proc)\
		return;\
	to_proc = t->to_proc;\
\
	if (reply) {\
		binder_reply_handler(task_tgid_nr(current), current, to_proc->pid, to_proc->tsk, false, tr);\
	} else if (t->from) {\
		if (t->from->proc) {\
			binder_trans_handler(t->from->proc->pid, t->from->proc->tsk, to_proc->pid, to_proc->tsk, false, tr);\
		}\
	} else { // oneway=1\
		binder_trans_handler(task_tgid_nr(current), current, to_proc->pid, to_proc->tsk, true, tr);\
\
		target_alloc = &to_proc->alloc;\
		if (target_alloc->free_async_space < (target_alloc->buffer_size / 10 + 0x300)) {\
			binder_overflow_handler(task_tgid_nr(current), current, to_proc->pid, to_proc->tsk, true, tr);\
		}\
	}\
}\
#endif /* CONFIG_REKERNEL */\
' \
-e '/trace_binder_transaction(reply, t, target_node);/i\
#ifdef CONFIG_REKERNEL\
	rekernel_binder_transaction(reply, t, target_node, tr);\
#endif /* CONFIG_REKERNEL */'

sed -i common/kernel/signal.c \
-e '/#include <asm\/cacheflush.h>/a\
#ifdef CONFIG_REKERNEL\
#include <uapi/asm/signal.h>\
#include <../drivers/rekernel/rekernel.h>\
#endif /* CONFIG_REKERNEL */' \
-e '/int ret = -ESRCH;/a\
#ifdef CONFIG_REKERNEL\
	if (sig == SIGKILL || sig == SIGTERM || sig == SIGABRT || sig == SIGQUIT)\
		rekernel_report(SIGNAL, sig, task_tgid_nr(current), current, task_tgid_nr(p), p, false, NULL);\
#endif /* CONFIG_REKERNEL */'
