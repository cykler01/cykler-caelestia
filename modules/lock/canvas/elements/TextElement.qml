import QtQuick

// Words of the user's own, which can run over several lines
TextBlock {
    content: opts.text ?? ""
    wrapMode: Text.NoWrap
}
