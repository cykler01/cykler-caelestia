.pragma library

// The part of a monitor that windows can occupy, in Hyprland's logical layout coordinates,
// which is what a window's `at` and `size` are given in. That is the monitor's physical
// size divided by its scale (with width and height swapped when it is rotated), less the
// edges Hyprland reserves for the bar and gaps. Null until the monitor's data has arrived.
function usableRect(ipc) {
    if (!ipc || !ipc.width || !ipc.height)
        return null;

    const scale = ipc.scale > 0 ? ipc.scale : 1;
    const rotated = (ipc.transform ?? 0) % 2 === 1;
    const width = (rotated ? ipc.height : ipc.width) / scale;
    const height = (rotated ? ipc.width : ipc.height) / scale;
    const reserved = ipc.reserved ?? [0, 0, 0, 0]; // left, top, right, bottom

    return {
        x: ipc.x + reserved[0],
        y: ipc.y + reserved[1],
        width: Math.max(1, width - reserved[0] - reserved[2]),
        height: Math.max(1, height - reserved[1] - reserved[3])
    };
}
