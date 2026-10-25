extends RefCounted
# Return from the coroutine before ending the engine. Resumed test frames can
# otherwise retain temporary playback/query references until the next frame.
static func finish(tree:SceneTree,code:int):
    var timer=Timer.new()
    timer.one_shot=true
    timer.wait_time=0.2
    timer.process_mode=Node.PROCESS_MODE_ALWAYS
    tree.root.add_child(timer)
    timer.timeout.connect(tree.quit.bind(code))
    timer.start()
