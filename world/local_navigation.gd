extends RefCounted
# Bounded geometric planning only. The caller supplies a remembered destination;
# this module neither senses the player nor changes the infected state machine.
const STEP = 20.0
const EXTENT = 11
const MAX_EXPANSIONS = 220
const DIRECTIONS = [Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,0),
    Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,-1),Vector2i(-1,1)]

static func plan(start: Vector2, target: Vector2, clear: Callable) -> Dictionary:
    var goal = start + (target-start).limit_length(180.0)
    var open = [Vector2i.ZERO]
    var costs = {Vector2i.ZERO:0.0}
    var parents = {}
    var closed = {}
    var expanded = 0
    while not open.is_empty() and expanded < MAX_EXPANSIONS:
        var best = 0
        var best_score = INF
        for i in range(open.size()):
            var p = start + Vector2(open[i]) * STEP
            var score = float(costs[open[i]]) + p.distance_to(goal)
            if score < best_score:
                best_score = score
                best = i
        var cell = open[best]
        open.remove_at(best)
        var position = start + Vector2(cell) * STEP
        expanded += 1
        if position.distance_to(goal) <= STEP * 1.5 and clear.call(position,goal):
            var path = [goal]
            var current = cell
            while current != Vector2i.ZERO:
                path.push_front(start + Vector2(current) * STEP)
                current = parents[current]
            # String pulling uses the whole body, so diagonal corner cutting is
            # rejected exactly as it is during physical movement.
            var smooth = []
            var anchor = start
            while not path.is_empty():
                var next = path.size()-1
                while next > 0 and not clear.call(anchor,path[next]):
                    next -= 1
                anchor = path[next]
                smooth.append(anchor)
                path = path.slice(next+1)
            return {"path":smooth,"expanded":expanded}
        closed[cell] = true
        for direction in DIRECTIONS:
            var neighbor = cell + direction
            if abs(neighbor.x) > EXTENT or abs(neighbor.y) > EXTENT or closed.has(neighbor):
                continue
            var next_position = start + Vector2(neighbor) * STEP
            var cost = float(costs[cell]) + position.distance_to(next_position)
            if costs.has(neighbor) and float(costs[neighbor]) <= cost:
                continue
            if not clear.call(position,next_position):
                continue
            costs[neighbor] = cost
            parents[neighbor] = cell
            if not open.has(neighbor):
                open.append(neighbor)
    return {"path":[],"expanded":expanded}
