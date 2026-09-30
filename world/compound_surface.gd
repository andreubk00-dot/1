extends RefCounted

# Small cached pixel tiles: opaque authored yards keep their own surface instead
# of exposing the city's baked crossroad. No geometry, collision or loot changes.
static var cache:Dictionary = {}

static func texture(surface:Color,vegetated:bool) -> Texture2D:
    var key = surface.to_html() + str(vegetated)
    if cache.has(key):
        return cache[key]
    var img = Image.create(256,256,false,Image.FORMAT_RGBA8)
    img.fill(surface)
    var rng = RandomNumberGenerator.new()
    rng.seed = 117101 + int(surface.r * 1000)
    for i in range(6400):
        var x = rng.randi_range(0,255)
        var y = rng.randi_range(0,255)
        var shade = rng.randf_range(-0.045,0.045)
        img.set_pixel(x,y,Color(surface.r+shade,surface.g+shade,surface.b+shade,1.0))
    if not vegetated:
        # Irregular slab seams and short cracks, subdued enough to preserve loot
        # readability. All pixels are opaque; streets cannot bleed through.
        var seam = surface.darkened(0.24)
        for y in [63,191]:
            for x in range(256):
                if rng.randf() > 0.10:
                    img.set_pixel(x,y,seam)
        for x in [47,175]:
            for y in range(256):
                if rng.randf() > 0.15:
                    img.set_pixel(x,y,seam)
        for i in range(9):
            var point = Vector2i(rng.randi_range(8,232),rng.randi_range(8,232))
            for step in range(rng.randi_range(9,24)):
                point += Vector2i(1,rng.randi_range(-1,1))
                if point.x < 256 and point.y >= 0 and point.y < 256:
                    img.set_pixelv(point,seam)
    var result = ImageTexture.create_from_image(img)
    cache[key] = result
    return result
