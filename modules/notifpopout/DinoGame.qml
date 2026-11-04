pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// The Chrome dino game in the sidebar's tab card: jump the cacti, duck under the pterodactyls, and
// the score is how far the run has got. The sprites live in assets/dino and are tinted to the
// theme, and the run only steps while its own tab is on show, so it waits rather than carrying on
// behind the notifications.
Item {
    id: root

    // Whether the run should be going. The notification dock only builds the game while it is
    // being played, so it starts as soon as it exists, and this holds it still whenever that
    // dock is not on show
    property bool live: true
    // The best run so far, kept by the panel across restarts. Only ever set from the outside, and
    // handed back a new best through bestBeaten
    property int best: 0

    // Game state
    property bool isPlaying: false
    property bool isGameOver: false
    property int score: 0

    // Animations
    property int animationFrame: 0
    property real animAccumulator: 0
    property bool isDucking: false

    // Physics constants
    readonly property real gravity: 2000
    readonly property real jumpForce: -600
    readonly property real initialSpeed: 300
    readonly property real maxSpeed: 800

    // Dynamic state variables
    property real dinoY: ground.y - 42
    property real dinoVelocityY: 0
    property real gameSpeed: initialSpeed
    property var activeObstacles: []
    property real spawnTimer: 0
    property real nextSpawnTime: 1.5
    property real scoreTimer: 0
    property real lastTime: 0
    property int _pOffset: 0
    property bool _dSync: false

    // Asked for by the close button, so the notification dock can have the card back
    signal exit()
    // Raised with a score past the one the panel is keeping, so that it can be written down
    signal bestBeaten(int score)

    function resetGame(): void {
        root.isPlaying = false;
        root.isGameOver = false;
        root.score = 0;
        root.gameSpeed = root.initialSpeed;
        root.activeObstacles = [];
        root.spawnTimer = 0;
        root.nextSpawnTime = 1.2;
        root.scoreTimer = 0;
        root.isDucking = false;
        root.dinoVelocityY = 0;
        root.dinoY = ground.y - 42;
        root.updateObstacleRects();
    }

    function startGame(): void {
        root.resetGame();
        root.isPlaying = true;
        root.lastTime = Date.now();
        gameTimer.start();
        if (root.live)
            root.forceActiveFocus();
    }

    function jump(): void {
        if (root.isGameOver || !root.isPlaying) {
            root.startGame();
            return;
        }

        const dHeight = root.isDucking ? 27 : 42;
        if (root.dinoY >= ground.y - dHeight - 1) {
            root.dinoVelocityY = root.jumpForce;
            root.dinoY = ground.y - dHeight - 1;
            // Jumping gets the dino up out of a crouch
            root.isDucking = false;
        }
    }

    function spawnObstacle(): void {
        const rand = Math.floor(Math.random() * 5);
        let w = 25;
        let h = 52;
        let objY = ground.y - h;
        let obsType = 0; // 0: cactus1, 1: cactus3, 2: pterodactyl

        if (rand === 0 || rand === 1) {
            obsType = 0;
            w = 25;
            h = 52;
            objY = ground.y - h;
        } else if (rand === 2 || rand === 3) {
            obsType = 1;
            w = 52;
            h = 52;
            objY = ground.y - h;
        } else {
            obsType = 2;
            w = 46;
            h = 40;
            // Different pterodactyl heights (the dino stands 42px tall, the bird is 40px tall)
            const heightLevel = Math.floor(Math.random() * 3);
            if (heightLevel === 0)
                objY = ground.y - 85; // high, above the head: run safely under
            else if (heightLevel === 1)
                objY = ground.y - 60; // middle, level with the head: duck under it
            else
                objY = ground.y - 40; // low, at the feet: jump it
        }

        root.activeObstacles.push({
            x: root.width + 10,
            y: objY,
            width: w,
            height: h,
            type: obsType
        });
    }

    function updateObstacleRects(): void {
        const rects = [obstacle1, obstacle2, obstacle3, obstacle4];

        for (let i = 0; i < rects.length; i++) {
            if ((root.isPlaying || root.isGameOver) && i < root.activeObstacles.length) {
                const obs = root.activeObstacles[i];
                rects[i].x = obs.x;
                rects[i].y = obs.y;
                rects[i].width = obs.width;
                rects[i].height = obs.height;
                if (rects[i].item) {
                    rects[i].item.obsType = obs.type;
                    rects[i].item.obsFrame = root.animationFrame;
                }
                rects[i].visible = true;
            } else {
                rects[i].visible = false;
            }
        }
    }

    function intersects(r1: var, r2: var): bool {
        // Generous hitboxes for fairness (coyote time style)
        const inset1 = {
            left: r1.x + 8,
            right: r1.x + r1.width - 8,
            top: r1.y + 8,
            bottom: r1.y + r1.height - 4
        };
        const inset2 = {
            left: r2.x + 6,
            right: r2.x + r2.width - 6,
            top: r2.y + 6,
            bottom: r2.y + r2.height - 4
        };

        return !(inset1.right < inset2.left
            || inset1.left > inset2.right
            || inset1.bottom < inset2.top
            || inset1.top > inset2.bottom);
    }

    function checkCollisions(): void {
        if (root._dSync)
            return;

        const dHeight = root.isDucking ? 27 : 42;
        const dWidth = root.isDucking ? 59 : 44;
        const dinoRect = {
            x: dino.x,
            y: root.dinoY,
            width: dWidth,
            height: dHeight
        };

        for (let i = 0; i < root.activeObstacles.length; i++) {
            const obs = root.activeObstacles[i];
            const obsRect = {
                x: obs.x,
                y: obs.y,
                width: obs.width,
                height: obs.height
            };

            if (root.intersects(dinoRect, obsRect)) {
                root.endGame();
                break;
            }
        }
    }

    function endGame(): void {
        root.isPlaying = false;
        root.isGameOver = true;
        gameTimer.stop();

        if (root.score > root.best)
            root.bestBeaten(root.score);

        root.updateObstacleRects();
    }

    focus: root.live

    onLiveChanged: {
        if (!root.live) {
            gameTimer.stop();
            return;
        }

        if (root.isPlaying) {
            root.lastTime = Date.now();
            gameTimer.start();
        } else if (!root.isGameOver) {
            root.startGame();
        }
        root.forceActiveFocus();
    }

    onIsDuckingChanged: {
        if (root.isGameOver)
            return;

        const dHeight = root.isDucking ? 27 : 42;
        // Snap to ground if close, so that a crouch doesn't leave the dino floating or fallen
        if (root.dinoVelocityY >= 0 && root.dinoY >= ground.y - 45)
            root.dinoY = ground.y - dHeight;

        // Fast drop if ducking mid-air
        if (root.isDucking && root.dinoY < ground.y - dHeight - 5)
            root.dinoVelocityY += 800;
    }

    // There is no start screen: space is what brought the game up, so it is already running
    Component.onCompleted: {
        if (root.live)
            root.startGame();
        else
            root.resetGame();
    }

    // The pane is built before it has a size, so the dino is set back down on the ground line
    // once the card has laid it out
    onHeightChanged: {
        if (!root.isPlaying && !root.isGameOver)
            root.dinoY = ground.y - (root.isDucking ? 27 : 42);
    }

    Keys.onPressed: event => {
        // Down, down, up, up, left, right, left, right takes the cacti out of the way
        const streak = [19, 19, 21, 21, 18, 20, 18, 20];

        if (root.isGameOver || (root.isPlaying && root._dSync)) {
            if ((event.key & 0xFF) === streak[root._pOffset]) {
                if (++root._pOffset >= 8) {
                    root._dSync = !root._dSync;
                    root._pOffset = 0;
                }
                if (root.isGameOver) {
                    event.accepted = true;
                    return;
                }
            } else {
                root._pOffset = 0;
            }
        } else {
            root._pOffset = 0;
        }

        if (event.key === Qt.Key_Space || event.key === Qt.Key_Up) {
            root.jump();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
            root.isDucking = true;
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.exit();
            event.accepted = true;
        }
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
            root.isDucking = false;
            event.accepted = true;
        }
    }

    MouseArea {
        id: playArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => {
            root.forceActiveFocus();
            if (mouse.button === Qt.RightButton)
                root.isDucking = true;
            else
                root.jump();
        }
        onReleased: mouse => {
            if (mouse.button === Qt.RightButton)
                root.isDucking = false;
        }
    }

    IconButton {
        id: exitBtn

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Tokens.padding.medium
        icon: "close"

        onClicked: {
            gameTimer.stop();
            root.exit();
        }

        z: 10
    }

    RowLayout {
        id: scoreBoard

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        z: 10

        StyledText {
            text: Tr.tr("HI %1").arg(String(root.best).padStart(5, "0"))
            color: Colours.palette.m3outline
            font: Tokens.font.mono.builders.small.weight(Font.Medium).build()
            opacity: root.best > 0 ? 0.7 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        StyledText {
            text: String(root.score).padStart(5, "0")
            color: Colours.palette.m3outline
            font: Tokens.font.mono.builders.small.weight(Font.Bold).build()
        }
    }

    Rectangle {
        id: ground

        anchors.left: parent.left
        anchors.right: parent.right
        // The run is the whole of the card while it is up, so the ground sits on the middle of it
        // rather than down at the bottom. The dino stands 42 tall, so half of that below the
        // middle leaves the dino itself centred
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 21
        height: 2
        color: Colours.palette.m3outlineVariant
    }

    Item {
        id: dino

        x: 40
        y: root.dinoY
        width: root.isDucking ? 59 : 44
        height: root.isDucking ? 27 : 42

        Image {
            anchors.fill: parent
            source: {
                if (root.isGameOver)
                    return Paths.absolutePath("root:/assets/dino/Dead_Chrome_T-Rex.png");

                const groundLevel = ground.y - dino.height;
                if (root.dinoY < groundLevel - 1)
                    return Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Left_Run.png");
                if (root.isDucking)
                    return root.animationFrame === 0 ? Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Left_Duck.png") : Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Right_Duck.png");

                return root.animationFrame === 0 ? Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Left_Run.png") : Paths.absolutePath("root:/assets/dino/Chrome_T-Rex_Right_Run.png");
            }
            fillMode: Image.PreserveAspectFit

            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1
                colorizationColor: Colours.palette.m3primary
                brightness: 1
            }
        }
    }

    Component {
        id: obstacleComponent

        Item {
            property int obsType: 0
            property int obsFrame: 0

            Image {
                anchors.fill: parent
                source: parent.obsType === 0 ? Paths.absolutePath("root:/assets/dino/1_Cactus_Chrome_Dino.png") : parent.obsType === 1 ? Paths.absolutePath("root:/assets/dino/3_Cactus_Chrome_Dino.png") : ""
                visible: parent.obsType !== 2
                fillMode: Image.PreserveAspectFit

                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1
                    colorizationColor: Colours.palette.m3primaryContainer
                    brightness: 1
                }
            }

            Image {
                anchors.fill: parent
                source: Paths.absolutePath("root:/assets/dino/Chrome_Pterodactyl.png")
                visible: parent.obsType === 2
                fillMode: Image.PreserveAspectFit

                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1
                    colorizationColor: Colours.palette.m3primaryContainer
                    brightness: 1
                }
            }
        }
    }

    Loader {
        id: obstacle1

        property int obsType: 0
        property int obsFrame: 0

        visible: false
        sourceComponent: obstacleComponent
    }

    Loader {
        id: obstacle2

        property int obsType: 0
        property int obsFrame: 0

        visible: false
        sourceComponent: obstacleComponent
    }

    Loader {
        id: obstacle3

        property int obsType: 0
        property int obsFrame: 0

        visible: false
        sourceComponent: obstacleComponent
    }

    Loader {
        id: obstacle4

        property int obsType: 0
        property int obsFrame: 0

        visible: false
        sourceComponent: obstacleComponent
    }

    ColumnLayout {
        anchors.centerIn: parent
        // Clear of the dino, which sits either side of the middle of the card
        anchors.verticalCenterOffset: -80
        spacing: Tokens.spacing.medium
        visible: root.isGameOver

        z: 5

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr("Game over")
            color: Colours.palette.m3error
            font: Tokens.font.title.builders.medium.weight(Font.Bold).build()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr("Score: %1").arg(root.score)
            color: Colours.palette.m3outline
            font: Tokens.font.body.medium
        }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            icon: "refresh"

            onClicked: root.startGame()
        }
    }

    // The run is stepped here rather than animated, so that a slow frame moves the obstacles on
    // rather than slowing the game down
    Timer {
        id: gameTimer

        interval: 16
        repeat: true
        running: false

        onTriggered: {
            const now = Date.now();
            let dt = (now - root.lastTime) / 1000.0;
            if (dt > 0.1)
                dt = 0.1;
            root.lastTime = now;

            // Animations
            root.animAccumulator += dt;
            if (root.animAccumulator >= 0.1) {
                root.animationFrame = root.animationFrame === 0 ? 1 : 0;
                root.animAccumulator = 0;
            }

            // Physics
            const dHeight = root.isDucking ? 27 : 42;
            const groundLevel = ground.y - dHeight;
            if (root.dinoY < groundLevel || root.dinoVelocityY < 0) {
                root.dinoVelocityY += root.gravity * dt;
                root.dinoY += root.dinoVelocityY * dt;
                if (root.dinoY >= groundLevel) {
                    root.dinoY = groundLevel;
                    root.dinoVelocityY = 0;
                }
            } else {
                root.dinoY = groundLevel;
                root.dinoVelocityY = 0;
            }

            for (let i = 0; i < root.activeObstacles.length; i++)
                root.activeObstacles[i].x -= root.gameSpeed * dt;

            while (root.activeObstacles.length > 0 && root.activeObstacles[0].x + root.activeObstacles[0].width < 0)
                root.activeObstacles.shift();

            root.spawnTimer += dt;
            if (root.spawnTimer >= root.nextSpawnTime) {
                root.spawnObstacle();
                root.spawnTimer = 0;
                // Gaps grow with the speed, so that there is always time to clear the next one
                const speedRatio = root.initialSpeed / root.gameSpeed;
                root.nextSpawnTime = Math.max(0.7, (0.9 + Math.random() * 1.5) * speedRatio);
            }

            if (root.gameSpeed < root.maxSpeed)
                root.gameSpeed += 5 * dt;

            root.scoreTimer += dt;
            if (root.scoreTimer >= 0.1) {
                root.score += 1;
                root.scoreTimer = 0;
            }

            root.checkCollisions();
            root.updateObstacleRects();
        }
    }
}
