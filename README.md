# NamedPipeExchange
Includes FWIOCompletionPipes - writed by Rouse_ (http://rouse.drkb.ru/network.php#fwiocompletionpipe)
Original module contains restriction - sending and receiving packets with max size = MAXWORD.

Module uNamedPipesExchange removes this restriction. Now we can send data with max size = High(integer)

Main features of the original module, like blocking mode and blocking server after activating - without changes.

In the sample (ProjectNamedPipesExchange) shown, how to avoid blocking (by using TThread).
