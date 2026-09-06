import QtQuick
import Nilastia
import Nilastia.Config
import qs.services

Canvas {
    id: root

    property var points: []
    property color glowColor: Colours.palette.m3primary || "#00f0ff"

    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Immediate

    onPointsChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        if (!points || points.length < 2) return;

        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        // Pass 1: Outer luminous diffuse neon bloom
        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (var i = 1; i < points.length; i++) {
            ctx.lineTo(points[i].x, points[i].y);
        }
        ctx.strokeStyle = Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.4);
        ctx.lineWidth = 14;
        ctx.stroke();

        // Pass 2: Secondary color shimmer
        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (var j = 1; j < points.length; j++) {
            ctx.lineTo(points[j].x, points[j].y);
        }
        ctx.strokeStyle = Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.8);
        ctx.lineWidth = 7;
        ctx.stroke();

        // Pass 3: White hot brilliant core
        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (var k = 1; k < points.length; k++) {
            ctx.lineTo(points[k].x, points[k].y);
        }
        ctx.strokeStyle = "#ffffff";
        ctx.lineWidth = 3.5;
        ctx.stroke();

        // Particle sparkle at current tip
        if (points.length > 0) {
            var tip = points[points.length - 1];
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.arc(tip.x, tip.y, 4, 0, 2 * Math.PI);
            ctx.fill();
        }
    }
}
