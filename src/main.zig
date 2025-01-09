// raylib-zig (c) Nikolas Wipper 2023
const std = @import("std");
const rl = @import("raylib");
const math = std.math;
const rlm = rl.math;
const Vector2 = rl.Vector2;

const L_THICKNESS = 2.0;
const SHIP_SPEED = 2.0;
const ROT_SPEED = 0.02;
const TIME_BETWEEN_BULLETS = 0.3;
const BULLET_SPEED = 1.5;
const SCALE = 30;
const SIZE = Vector2.init(1280, 960);

const Ship = struct {
    pos: Vector2,
    vel: f32,
    rot: f32,
};

const Bullet = struct {
    pos: Vector2,
    vel: Vector2,
};

const Asteroid = struct {
    pos: Vector2,
    vel: Vector2,
};

const State = struct {
    ship: Ship,
    bullets: std.ArrayList(Bullet),
    asteroids: std.ArrayList(Asteroid),
    now: f32,
    delta: f32,
    last_bullet: f32,
    score: u8,
    rand: std.rand.Random,
};

fn drawLine(position: Vector2, scale: f32, rotation: f32, points: []const Vector2) void {
    for (0..points.len - 1) |i| {
        rl.drawLineEx(
            rlm.vector2Add(rlm.vector2Scale(rlm.vector2Rotate(points[i], rotation), scale), position),
            rlm.vector2Add(rlm.vector2Scale(rlm.vector2Rotate(points[i + 1], rotation), scale), position),
            L_THICKNESS,
            rl.Color.white,
        );
    }
}

fn drawShip(ship: Ship) void {
    drawLine(
        ship.pos,
        SCALE,
        ship.rot - (math.pi / 2.0),
        &.{
            Vector2.init(-0.4, -0.5),
            Vector2.init(0.0, 0.5),
            Vector2.init(0.4, -0.5),
            Vector2.init(0.3, -0.4),
            Vector2.init(-0.3, -0.4),
        },
    );
}

fn drawBullets(bullets: std.ArrayList(Bullet)) void {
    for (bullets.items) |*bullet| {
        drawLine(
            bullet.pos,
            SCALE * 0.5,
            0.0,
            &.{
                Vector2.init(0, 0),
                bullet.vel,
            },
        );
    }
}

fn drawAsteroids(asteroids: std.ArrayList(Asteroid)) void {
    for (asteroids.items) |*asteroid| {
        drawLine(
            asteroid.pos,
            SCALE * 0.5,
            0,
            &.{
                Vector2.init(-0.5, -0.5),
                Vector2.init(-0.75, 0),
                Vector2.init(-0.5, 0.5),
                Vector2.init(0, -0.75),
                Vector2.init(0.5, 0.5),
                Vector2.init(0.75, 0),
                Vector2.init(0.5, -0.5),
                Vector2.init(0, -0.75),
            },
        );
    }
}

fn moveShip(ship: *Ship) void {
    ship.vel = 0;
    if (rl.isKeyDown(rl.KeyboardKey.w)) {
        ship.vel = SHIP_SPEED;
    }
    if (rl.isKeyDown(rl.KeyboardKey.s)) {
        ship.vel = -SHIP_SPEED;
    }
    if (rl.isKeyDown(rl.KeyboardKey.a)) {
        ship.rot += -ROT_SPEED;
    }
    if (rl.isKeyDown(rl.KeyboardKey.d)) {
        ship.rot += ROT_SPEED;
    }

    ship.pos = rlm.vector2Add(
        ship.pos,
        Vector2.init(
            ship.vel * math.cos(ship.rot),
            ship.vel * math.sin(ship.rot),
        ),
    );
}

fn moveBullets(bullets: std.ArrayList(Bullet)) void {
    for (bullets.items) |*bullet| {
        bullet.pos = rlm.vector2Add(bullet.pos, bullet.vel);
    }
}

fn removeOutsideBullets(bullets: *std.ArrayList(Bullet)) void {
    const len = bullets.items.len;
    if (len > 1) {
        for (1..len) |i| {
            const bullet = bullets.items[len - i];
            if (bullet.pos.x < 0 or bullet.pos.x > SIZE.x or
                bullet.pos.y < 0 or bullet.pos.y > SIZE.y)
            {
                _ = bullets.orderedRemove(len - i);
            }
        }
    }
}

// fn addAsteroid(asteroids: std.ArrayList(Asteroid), pnrg: std.rand.Random) void {
//     const rand_pos = Vector2.init(std.rand.int(pnrg.intRangeLessThan(i32, , less_than: T), comptime T: type), y: f32)
// }

fn update(state: *State) !void {
    moveShip(&state.ship);

    if (rl.isMouseButtonDown(rl.MouseButton.left)) {
        if (state.now - state.last_bullet > TIME_BETWEEN_BULLETS) {
            const direction = Vector2.init(
                BULLET_SPEED * math.cos(state.ship.rot),
                BULLET_SPEED * math.sin(state.ship.rot),
            );
            const bullet: Bullet = .{
                .pos = rlm.vector2Add(state.ship.pos, rlm.vector2Scale(direction, 5)),
                .vel = direction,
            };
            try state.bullets.append(bullet);
            state.last_bullet = state.now;
        }
    }
    moveBullets(state.bullets);
    removeOutsideBullets(&state.bullets);

    addAsteroid(state.asteroids);
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    // Initialization
    //--------------------------------------------------------------------------------------
    rl.initWindow(SIZE.x, SIZE.y, "Asteroids");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    var prng = std.rand.Xoshiro256.init(@bitCast(std.time.timestamp()));

    var state: State = .{
        .ship = .{
            .pos = rlm.vector2Scale(SIZE, 0.5),
            .vel = 0.0,
            .rot = 0.0,
        },
        .now = 0.0,
        .delta = 0.0,
        .last_bullet = -1.0,
        .score = 0,
        .rand = prng.random(),
        .bullets = std.ArrayList(Bullet).init(allocator),
        .asteroids = std.ArrayList(Asteroid).init(allocator),
    };
    defer state.bullets.deinit();

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        const start_time = rl.getTime();
        state.delta = rl.getFrameTime();

        state.now += state.delta;

        // Update
        try update(&state);

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        drawShip(state.ship);
        drawBullets(state.bullets);
        drawAsteroids(state.asteroids);

        rl.drawText(rl.textFormat("Score: %08i", .{state.score}), 10, 10, 25, rl.Color.white);
        //----------------------------------------------------------------------------------
        std.debug.print("Frame time: {d} ms\n", .{(rl.getTime() - start_time) * 1000.0});
    }
}
