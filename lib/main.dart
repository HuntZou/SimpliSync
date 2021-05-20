import 'dart:math';
import 'package:transparent_image/transparent_image.dart';
import 'package:universal_html/html.dart' as html;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimpliSync',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: MyHomePage(title: 'SimpliSync'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // ---------------------State----------------------------
  List<Map> fileNames = <Map>[];
  List<SyncData> fetchedDatas = <SyncData>[];

  String auth = "Default";
  List<String> localAuths = <String>[];

  bool holdSubmiting = false;

  int loading;

  List<String> uploadingFileNames = <String>[];

  int pageIndex;
  int pageSize;
  // ------------------------------------------------------

  String appId = "Iajwj1JrQYGbM4eiXtEvGbM7-MdYXbMMI";
  String appKey = "UGKm41pjP0Tbg0UzoQGnSMqs";

  TextEditingController textEditingController = TextEditingController();
  FocusNode textInputFieldFocusNode;

  TextEditingController authEditingController = TextEditingController();

  List<PlatformFile> files = [];

  void pickFiles() async {
    FilePickerResult filePickerResult =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    this.setState(() {
      this.fileNames = filePickerResult.files
          .map((f) => {
                "originName": f.name,
                "uniqueName": DateTime.now().microsecondsSinceEpoch.toString() +
                    "_" +
                    (Random().nextInt(8999) + 1000).toString() +
                    "_" +
                    f.name,
                "type": f.extension,
                "uploadStatus": "ready"
              })
          .toList();
    });

    this.files = filePickerResult.files;
  }

  Widget readyUploadFileItem(String fileName) {
    return Padding(
      padding: EdgeInsets.all(5),
      child: Column(
        children: [
          this.uploadingFileNames?.contains(fileName) ?? false
              ? Icon(
                  Icons.upload_file,
                  color: Colors.green,
                )
              : Icon(Icons.file_present),
          Text((this.uploadingFileNames?.contains(fileName) ?? false
                  ? "uploading "
                  : "") +
              (fileName.length > 10
                  ? fileName.substring(0, 10) + ".."
                  : fileName)),
        ],
      ),
    );
  }

  void _submit([String auth = "Default", bool canBeDefault = false]) {
    if ((this.textEditingController.text == null ||
            this.textEditingController.text.isEmpty) &&
        (this.files?.isEmpty ?? true)) return;

    if (canBeDefault && auth == "Default") {
      this._showAuthInputDialog(onApprove: (v) => this._updateAuthAndPush(v));
    } else {
      this._sendData(auth: auth);
    }
  }

  void _sendData({auth = "Default"}) {
    this._sendPushTextRequest(auth, () => this._uploadFiles(this.files));
  }

  void _sendPushTextRequest([String auth = "Default", Function onSuccess]) {
    String type = "";
    if ((this.textEditingController.text == null ||
            this.textEditingController.text.isEmpty) &&
        (this.files?.isNotEmpty ?? false)) {
      type = "FILES";
    } else if ((this.textEditingController.text != null &&
            this.textEditingController.text.isNotEmpty) &&
        (this.files?.isEmpty ?? true)) {
      type = "TEXT";
    } else if ((this.textEditingController.text != null &&
            this.textEditingController.text.isNotEmpty) &&
        (this.files?.isNotEmpty ?? false)) {
      type = "MULTIMEDIA";
    } else {
      this._showToast("Neither text nor files are specified", Colors.red);
      return;
    }

    this.startLoading();
    Dio().post(
        "https://${appId.substring(0, 8)}.api.lncldglobal.com/1.1/classes/SyncContent",
        options: Options(headers: {
          "X-LC-Id": appId,
          "X-LC-Key": appKey,
          "Content-Type": "application/json"
        }),
        data: {
          "content": this.textEditingController.text,
          "type": type,
          "auth": auth ?? "Default",
          "files": this.fileNames
        }).whenComplete(() {
      this.loadingCompelete();
      onSuccess();
    }).then((resp) {
      if (resp.statusCode == 201) {
        this._showToast("Push Success", Colors.green);
        this.textEditingController.clear();
        this.fetchData();
      } else {
        this._showToast("Push Failed", Colors.red);
      }
    });
  }

  void loadingCompelete() {
    if (this.loading > 0) {
      this.setState(() {
        this.loading--;
      });
    } else {
      this.setState(() {
        this.loading = 0;
      });
    }
  }

  void startLoading() {
    if (this.loading < 0) {
      this.setState(() {
        this.loading = 1;
      });
    } else {
      this.setState(() {
        this.loading++;
      });
    }
  }

  void fetchData({int pageChange}) {
    this.setState(() {
      this.fetchedDatas.clear();
      this.pageIndex = (pageChange == null ? 0 : this.pageIndex + pageChange);
    });

    this.startLoading();

    Dio()
        .get(
          "https://${appId.substring(0, 8)}.api.lncldglobal.com/1.1/classes/SyncContent",
          queryParameters: {
            "limit": this.pageSize,
            "skip": this.pageSize * this.pageIndex,
            "order": "-updatedAt",
            "where": '{"auth":"${this.auth ?? "Default"}"}'
          },
          options: Options(headers: {
            "X-LC-Id": appId,
            "X-LC-Key": appKey,
            "Content-Type": "application/json"
          }),
        )
        .whenComplete(() => this.loadingCompelete())
        .then((resp) {
      if (resp.statusCode == 200) {
        this._showToast("Fetch success", Colors.green);
        List<SyncData> syncDataList = [];
        for (var data in resp.data['results']) {
          List<SyncFile> syncFiles = [];
          for (var file in data["files"] ?? []) {
            syncFiles.add(SyncFile(file["originName"], file["uniqueName"],
                file["type"], file["uploadStatus"]));
          }
          var syncData = SyncData(
              data["content"], syncFiles, data["auth"], data["objectId"]);
          syncDataList.add(syncData);
        }

        this.setState(() {
          this.fetchedDatas = syncDataList;
        });
      } else {
        this._showToast("Fetch failed", Colors.red);
      }
    });
  }

  void _showToast(String msg, [Color color]) {
    ScaffoldMessenger.of(this.context).hideCurrentSnackBar();

    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: Duration(seconds: 2),
      backgroundColor: color ?? Colors.black87,
    ));
  }

  Future<void> _uploadFiles(List<PlatformFile> files) async {
    for (int i = 0; i < files.length; i++) {
      PlatformFile f = files[i];
      var fileName = this.fileNames.firstWhere(
          (fileName) => fileName["originName"] == f.name)["uniqueName"];
      FormData data = new FormData.fromMap({
        'key': "simplisync/" + fileName,
        'file': MultipartFile.fromBytes(f.bytes, filename: fileName)
      });

      this.startLoading();
      this.setState(() {
        this.uploadingFileNames?.add(f.name);
      });
      var resp = await Dio()
          .post("https://simplisync.oss-cn-beijing.aliyuncs.com", data: data)
          .whenComplete(() {
        this.loadingCompelete();
        this.setState(() {
          this.uploadingFileNames?.remove(f.name);
        });
      });
      {
        if (resp.statusCode == 204) {
          this.setState(() {
            this.fileNames = this.fileNames
              ..removeWhere((fileName) => fileName["originName"] == f.name);
          });
        }
      }
    }
    this.files.clear();
  }

  Future<bool> _showAuthInputDialog({Function(String) onApprove}) {
    this.authEditingController.text = Random().nextInt(999999).toString();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create an auth code for secure share'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Input or Random one or From clipboard.'),
                TextField(
                  controller: authEditingController,
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("From clipboard"),
              onPressed: () async {
                var auth =
                    (await Clipboard.getData("text/plain"))?.text?.trim();
                if (auth == null || auth.isEmpty || auth.length > 16) {
                  this._showToast(
                      "Auth code must has 1~16 characters", Colors.red);
                } else {
                  onApprove(auth);
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Approve'),
              onPressed: () {
                var auth = this.authEditingController.text?.trim();
                onApprove(auth);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void turnPage(int pageChange) {
    if (this.pageIndex + pageChange < 0) return;
    this.fetchData(pageChange: pageChange);
  }

  void _updateAuthAndPush(String auth, {bool pushData = true}) {
    if (auth != null && auth != "Default") {
      this._setAuth(auth,
          afterSetting: pushData ? (v) => this._sendData(auth: v) : null);
    }
  }

  void _setAuth(String auth, {Function(String) afterSetting}) async {
    auth = auth?.trim();
    if (auth == null || auth.isEmpty || auth == this.auth) {
      return;
    }
    if (auth.length > 16) {
      this._showToast("Auth code must less then 16 characters");
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("auth", auth);
    if (!prefs.getStringList("localAuths").contains(auth)) {
      prefs.setStringList(
          "localAuths", prefs.getStringList("localAuths")..add(auth));
    }
    this.setState(() {
      this.auth = auth;
      this.localAuths = prefs.getStringList("localAuths");
    });
    if (afterSetting != null) {
      afterSetting(auth);
    }
    this.fetchData();
  }

  void _switchAuth({String auth}) {
    if (auth == null) {
      auth = "Default";
    }
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString("auth", auth));
    this.setState(() {
      this.auth = auth;
    });
    this.fetchData();
  }

  Future<void> _deleteAuth(String auth) async {
    var prefs = await SharedPreferences.getInstance();
    if (prefs.getStringList("localAuths").contains(auth)) {
      prefs.setStringList(
          "localAuths", prefs.getStringList("localAuths")..remove(auth));
      this.setState(() {
        this.localAuths = this.localAuths..remove(auth);
      });
      this._switchAuth();
    }
  }

  List<PopupMenuItem<String>> _showLocalAuths(BuildContext context) {
    var popupMenuList = this
        .localAuths
        .map((localAuth) => PopupMenuItem(
            value: localAuth,
            child: Flex(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              direction: Axis.horizontal,
              children: [
                Text(localAuth),
                localAuth == "Default"
                    ? Icon(Icons.no_encryption, color: Colors.blue)
                    : IconButton(
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        icon: Icon(
                          Icons.delete,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          this._deleteAuth(localAuth);
                          Navigator.pop(context);
                        })
              ],
            )))
        .toList();
    popupMenuList.add(PopupMenuItem(
      value: "ADD",
      child: Text("Add one"),
      textStyle: TextStyle(color: Colors.green),
    ));

    return popupMenuList;
  }

  Widget _localAuthSelect() {
    List<Widget> widgets = [];
    Widget result;

    for (int i = 0; i < this.localAuths.length; i++) {
      widgets.add(
        Row(
          children: [
            Expanded(
              child: DragTarget(
                onAccept: (v) {
                  if (this.loading > 0) {
                    this._showToast("Busy!!! You hear that?", Colors.red);
                  } else {
                    this._setAuth(this.localAuths[i],
                        afterSetting: (v) => this._submit(v, i != 0));
                  }
                },
                builder: (
                  BuildContext context,
                  List<dynamic> accepted,
                  List<dynamic> rejected,
                ) {
                  return ColoredBox(
                    color: i % 2 == 0 ? Colors.green : Colors.greenAccent,
                    child: Padding(
                      padding: EdgeInsets.only(top: 15, bottom: 15),
                      child: Center(
                        child: Text(this.localAuths[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    widgets.add(
      Row(
        children: [
          Expanded(
            child: DragTarget(
              onAccept: (v) {
                this._showAuthInputDialog(
                    onApprove: (v) => this._updateAuthAndPush(v,
                        pushData: ((this.textEditingController.text != null &&
                                this.textEditingController.text.isNotEmpty) ||
                            (this.files?.isNotEmpty ?? false))));
              },
              builder: (
                BuildContext context,
                List<dynamic> accepted,
                List<dynamic> rejected,
              ) {
                return ColoredBox(
                  color: Colors.lightGreenAccent,
                  child: Padding(
                    padding: EdgeInsets.only(top: 15, bottom: 15),
                    child: Center(
                      child: Text(
                        "Add one",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    result = Column(
      children: widgets,
    );
    return result;
  }

  @override
  void initState() {
    super.initState();

    this.pageIndex = 0;
    this.pageSize = 20;

    this.loading = 0;

    SharedPreferences.getInstance().then((prefs) {
      if (prefs.getStringList("localAuths") == null) {
        List<String> defaultAuths = <String>["Default"];
        prefs.setStringList("localAuths", defaultAuths);
      }

      this.setState(() {
        this.auth = prefs.getString('auth') ?? "Default";
        this.localAuths = prefs.getStringList("localAuths");
      });

      this.fetchData();
    });

    this.textInputFieldFocusNode = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    this.textInputFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Color(0xffB87FB1),
        actions: [
          PopupMenuButton(
            enabled: !(this.loading > 0),
            itemBuilder: (context) => this._showLocalAuths(context),
            initialValue: this.auth,
            child: Padding(
              padding: EdgeInsets.only(right: 10),
              child: Center(
                child: Text(this.auth),
              ),
            ),
            onSelected: (v) {
              if ("ADD" == v) {
                this._showAuthInputDialog(
                    onApprove: (auth) => this._setAuth(auth));
              } else {
                this._switchAuth(auth: v);
              }
            },
          )
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text("Input then Sync to all platform"),
            ),
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text("Feel free to contact me for any question or suggestion."),
            ),
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text("zouheng613@163.com"),
            ),
            Padding(
              padding: EdgeInsets.only(top: 30),
              child: Center(
                child: Text(
                  """
                每当我遇到自己不敢直视的困难时，
                我就会闭上双眼，
                想象自己是一个80岁的老人，
                为人生中曾放弃和逃避过的无数困难而懊悔不已，
                我会对自己说，
                能再年轻一次该有多好，
                然后我睁开眼睛：
                砰！
                我又年轻一次了。
                """,
                  style: TextStyle(fontSize: 9),
                ),
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => this.loading > 0 ? null : this.fetchData(),
        child: this.loading > 0
            ? Text(
                "loading",
                style: TextStyle(fontSize: 10),
              )
            : Icon(Icons.refresh),
      ),
      body: Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 30),
          child: Column(
            children: [
              Column(
                children: [
                  Container(
                    decoration:
                        BoxDecoration(border: Border.all(color: Colors.grey)),
                    child: Stack(
                      alignment: AlignmentDirectional.topEnd,
                      children: [
                        TextField(
                          decoration: null,
                          maxLines: 6,
                          controller: textEditingController,
                        ),
                        IconButton(
                            highlightColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            icon: Icon(
                              Icons.paste,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              Clipboard.getData("text/plain").then((value) {
                                if (value != null &&
                                    value.text != null &&
                                    value.text.isNotEmpty) {
                                  this.textEditingController.text += value.text;
                                }
                              });
                            }),
                      ],
                    ),
                  ),
                  Container(
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(
                            child: Container(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (buildContext, index) => this
                                .readyUploadFileItem(
                                    this.fileNames[index]["originName"]),
                            itemCount: this.fileNames.length,
                          ),
                        )),
                        Container(
                          child: GestureDetector(
                            child: Container(
                              width: 50,
                              color: Color(0xffB87FB1),
                              child: Center(
                                child: Icon(
                                  Icons.attach_file,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            onTap: () => this.pickFiles(),
                          ),
                        )
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Draggable(
                          feedbackOffset: Offset(0, -20),
                          data: this.auth,
                          onDragStarted: () => this.setState(() {
                            this.holdSubmiting = true;
                          }),
                          onDragEnd: (v) => this.setState(() {
                            this.holdSubmiting = false;
                          }),
                          axis: Axis.vertical,
                          child: Material(
                            color: Color(0xff858DBB),
                            child: InkWell(
                              splashColor: Colors.green,
                              highlightColor: Colors.white,
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 15, bottom: 15),
                                  child: Text(this.holdSubmiting
                                      ? "Press and Drag to select an auth code"
                                      : "Submit"),
                                ),
                              ),
                              onTap: () {
                                if (this.loading > 0) {
                                  this._showToast("Busy!!!", Colors.red);
                                } else {
                                  this._submit(this.auth);
                                }
                              },
                            ),
                          ),
                          feedback: Row(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: Text(
                                  "Submit with code --->",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      decoration: TextDecoration.none),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Visibility(
                      visible: this.holdSubmiting,
                      child: this._localAuthSelect())
                ],
              ),
              Expanded(
                  child: Padding(
                padding: EdgeInsets.only(top: 10),
                child: SyncDataList(
                    key: UniqueKey(), fetchedDatas: this.fetchedDatas),
              )),
              Row(
                children: [
                  Visibility(
                    visible: this.pageIndex > 0,
                    child: TextButton(
                      child: Text("Prev"),
                      onPressed: () =>
                          (this.pageIndex > 0 ? this.turnPage(-1) : null),
                    ),
                  ),
                  Visibility(
                    visible: (this.fetchedDatas?.length ?? 0) == this.pageSize,
                    child: TextButton(
                      child: Text("Next"),
                      onPressed: () =>
                          ((this.fetchedDatas?.length ?? 0) < this.pageSize
                              ? null
                              : this.turnPage(1)),
                    ),
                  ),
                ],
              ),
            ],
          )),
    );
  }
}

class SyncDataList extends StatefulWidget {
  final List<SyncData> fetchedDatas;
  SyncDataList({Key key, this.fetchedDatas}) : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return SyncDataListState(fetchedDatas);
  }
}

class SyncDataListState extends State<StatefulWidget> {
  final List<SyncData> fetchedDatas;
  SyncDataListState(this.fetchedDatas);
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (buildContext, index) {
        return DataListItem(
            key: UniqueKey(),
            data: this.fetchedDatas[index],
            index: index,
            onDeleted: (objectId) {
              this.setState(() {
                this
                    .fetchedDatas
                    .removeWhere((data) => data._leanCloudId == objectId);
              });
            });
      },
      itemCount: this.fetchedDatas?.length ?? 0,
    );
  }
}

class DataListItem extends StatefulWidget {
  const DataListItem({Key key, this.data, this.index, this.onDeleted})
      : super(key: key);
  final SyncData data;
  final int index;

  final Function(String) onDeleted;

  @override
  _DataListItemState createState() {
    return _DataListItemState(data);
  }
}

class _DataListItemState extends State<DataListItem> {
  _DataListItemState(this.data);
  bool showFiles;
  SyncData data;

  @override
  void initState() {
    super.initState();
    this.showFiles = false;
  }

  Future<void> _showImage(String imagePath) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Preview'),
          content: FadeInImage.memoryNetwork(
            image: imagePath,
            placeholder: kTransparentImage,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> downloadFile(String filePath,
      {String fileName = "Bingo"}) async {
    html.window.open(filePath, fileName);
  }

  Widget fetchedFileItem(SyncFile fileInfo, int index) {
    String filePath =
        "https://simplisync.oss-cn-beijing.aliyuncs.com/simplisync/" +
            fileInfo._uniqueName;
    return Padding(
      padding: EdgeInsets.all(5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text("${index + 1}. "),
              Icon(Icons.attach_file),
              Text(fileInfo._originName.length > 12
                  ? fileInfo._originName.substring(0, 12) + "..."
                  : fileInfo._originName)
            ],
          ),
          Row(
            children: [
              Visibility(
                visible: fileInfo._originName.endsWith("png") ||
                    fileInfo._originName.endsWith("jpg") ||
                    fileInfo._originName.endsWith("jpeg") ||
                    fileInfo._originName.endsWith("gif"),
                child: IconButton(
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    icon: Icon(Icons.remove_red_eye_outlined),
                    onPressed: () => this
                        ._showImage(filePath + "?x-oss-process=style/preview")),
              ),
              IconButton(
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  icon: Icon(Icons.file_download),
                  onPressed: () {
                    this.downloadFile(filePath);
                  }),
            ],
          ),
        ],
      ),
    );
  }

  void deleteData(String objectId) {
    String appId = "Iajwj1JrQYGbM4eiXtEvGbM7-MdYXbMMI";
    String appKey = "UGKm41pjP0Tbg0UzoQGnSMqs";

    ScaffoldMessenger.of(this.context).hideCurrentSnackBar();

    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
      content: Text("Deleteing object"),
      duration: Duration(seconds: 2),
      backgroundColor: Colors.green,
    ));

    Dio()
        .delete(
      "https://${appId.substring(0, 8)}.api.lncldglobal.com/1.1/classes/SyncContent/$objectId",
      options: Options(headers: {
        "X-LC-Id": appId,
        "X-LC-Key": appKey,
        "Content-Type": "application/json"
      }),
    )
        .then((resp) {
      if (resp.statusCode == 200) {
        widget.onDeleted(objectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
        color: widget.index % 2 == 0 ? Color(0xffEAECF7) : Colors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Padding(
                  padding: EdgeInsets.only(left: 10, top: 5),
                  child: SelectableText(
                    (data._content != null && data._content.isNotEmpty)
                        ? data._content
                        : DateTime.now().toIso8601String(),
                    maxLines: 6,
                    minLines: 1,
                  ),
                )),
                Row(
                  children: [
                    Visibility(
                      visible: (this.data._files?.length ?? 0) > 0,
                      child: IconButton(
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          icon: Icon(
                            this.showFiles ? Icons.eject : Icons.file_present,
                            semanticLabel: "Copy string",
                          ),
                          onPressed: () {
                            this.setState(() {
                              this.showFiles = !this.showFiles;
                            });
                          }),
                    ),
                    Visibility(
                      visible:
                          data._content != null && data._content.isNotEmpty,
                      child: IconButton(
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          icon: Icon(
                            Icons.content_copy_rounded,
                            semanticLabel: "Copy string",
                          ),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: data._content));
                            final snackBar = SnackBar(
                              content: Text('Copied'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            );
                            ScaffoldMessenger.of(context)
                                .showSnackBar(snackBar);
                          }),
                    ),
                    IconButton(
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        icon: Icon(
                          Icons.delete_outline,
                          semanticLabel: "Delete string",
                        ),
                        onPressed: () => this.deleteData(data._leanCloudId))
                  ],
                )
              ],
            ),
            Visibility(
              visible: (data._files?.length ?? 0) > 0 && this.showFiles,
              child: Container(
                height: 250,
                child: Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    itemBuilder: (buildContext, index) =>
                        this.fetchedFileItem(data._files[index], index),
                    itemCount: data._files?.length ?? 0,
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}

class SyncData {
  String _content;
  List<SyncFile> _files;
  String _auth;
  String _leanCloudId;
  SyncData(this._content, this._files, this._auth, this._leanCloudId);
}

class SyncFile {
  String _originName;
  String _uniqueName;
  String _type;
  String _uploadStatus;
  SyncFile(this._originName, this._uniqueName, this._type, this._uploadStatus);
  String get originName => this._originName;
  String get uniqueName => this._uniqueName;
  String get type => this._type;
  String get uploadStatus => this._uploadStatus;
}
