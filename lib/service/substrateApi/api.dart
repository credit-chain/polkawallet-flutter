import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:polka_wallet/page/profile/settings/remoteNodeListPage.dart';
import 'package:polka_wallet/service/substrateApi/apiAccount.dart';
import 'package:polka_wallet/service/substrateApi/apiAssets.dart';
import 'package:polka_wallet/service/substrateApi/apiGov.dart';
import 'package:polka_wallet/service/substrateApi/apiStaking.dart';
import 'package:polka_wallet/store/app.dart';

// global api instance
Api webApi;

class Api {
  Api(this.context, this.store);

  final BuildContext context;
  final AppStore store;

  ApiAccount account;
  ApiAssets assets;
  ApiStaking staking;
  ApiGovernance gov;

  Map<String, Function> _msgHandlers = {};
  FlutterWebviewPlugin _web;
  int _evalJavascriptUID = 0;

  void init() {
    account = ApiAccount(this);
    assets = ApiAssets(this);
    staking = ApiStaking(this);
    gov = ApiGovernance(this);

    _web = FlutterWebviewPlugin();

    _web.onStateChanged.listen((viewState) async {
      if (viewState.type == WebViewState.finishLoad) {
        print('webview loaded');
        DefaultAssetBundle.of(context)
            .loadString('lib/polkadot_js_service/dist/main.js')
            .then((String js) {
          print('js file loaded');
          // inject js file to webview
          _web.evalJavascript(js);

          // load keyPairs from local data
          account.initAccounts();
          // connect remote node
          connectNode();
        });
      }
    });

    _web.launch(
      'about:blank',
      javascriptChannels: [
        JavascriptChannel(
            name: 'PolkaWallet',
            onMessageReceived: (JavascriptMessage message) {
              print('received msg: ${message.message}');
              compute(jsonDecode, message.message).then((msg) {
                final msg = jsonDecode(message.message);
                final String path = msg['path'];
                var handler = _msgHandlers[path];
                if (handler == null) {
                  return;
                }
                handler(msg['data']);
                if (path.contains('uid=')) {
                  _msgHandlers.remove(path);
                }
              });
            }),
      ].toSet(),
      ignoreSSLErrors: true,
//        withLocalUrl: true,
//        localUrlScope: 'lib/polkadot_js_service/dist/',
      hidden: true,
    );
  }

  int getEvalJavascriptUID() {
    return _evalJavascriptUID++;
  }

  Future<dynamic> evalJavascript(String code) async {
    Completer c = new Completer();
    void onComplete(res) {
      c.complete(res);
    }

    String method = 'uid=${getEvalJavascriptUID()};${code.split('(')[0]}';
    _msgHandlers[method] = onComplete;

    String script = '$code.then(function(res) {'
        '  PolkaWallet.postMessage(JSON.stringify({ path: "$method", data: res }));'
        '}).catch(function(err) {'
        '  PolkaWallet.postMessage(JSON.stringify({ path: "log", data: err.message }));'
        '})';
    _web.evalJavascript(script);

    return c.future;
  }

  Future<void> connectNode() async {
    var defaultNode = Locale.cachedLocaleString.contains('zh')
        ? default_node_zh
        : default_node;
    String value = store.settings.endpoint.value ?? defaultNode['value'];
//    String value = store.settings.endpoint.value ?? default_node['value'];
    print(value);
    String res = await evalJavascript('settings.connect("$value")');
    if (res == null) {
      print('connect failed');
      store.settings.setNetworkName(null);
      return;
    }
    fetchNetworkProps();
  }

  Future<void> changeNode(String endpoint) async {
    store.settings.setNetworkLoading(true);
    store.staking.clearSate();
    store.gov.clearSate();
    String res = await evalJavascript('settings.changeEndpoint("$endpoint")');
    if (res == null) {
      print('connect failed');
      store.settings.setNetworkName(null);
      return;
    }
    fetchNetworkProps();
  }

  Future<void> fetchNetworkProps() async {
    List<dynamic> info = await Future.wait([
      evalJavascript('settings.getNetworkConst()'),
      evalJavascript('api.rpc.system.properties()'),
      evalJavascript('api.rpc.system.chain()'),
      assets.fetchBalance(store.account.currentAddress),
    ]);

    store.settings.setNetworkConst(info[0]);
    store.settings.setNetworkState(info[1]);
    store.settings.setNetworkName(info[2]);

    if (store.settings.customSS58Format['info'] == 'default') {
      account.setSS58Format(info[1]['ss58Format']);
    }

    List addresses = store.account.accountList.map((i) => i.address).toList();
    account.fetchAccountsIndex(addresses);
    account.getAddressIcons(addresses);
  }

  Future<void> updateBlocks() async {
    Map<int, bool> blocksNeedUpdate = Map<int, bool>();
    store.assets.txs.forEach((i) {
      if (store.assets.blockMap[i.block] == null) {
        blocksNeedUpdate[i.block] = true;
      }
    });
    String blocks = blocksNeedUpdate.keys.join(',');
    var data = await evalJavascript('account.getBlockTime([$blocks])');

    store.assets.setBlockMap(data);
  }

  Future<void> subscribeBestNumber() async {
    _msgHandlers['bestNumber'] = (data) {
      store.gov.setBestNumber(data as int);
    };
    evalJavascript('gov.subBestNumber()');
  }

  Future<void> unsubscribeBestNumber() async {
    _web.evalJavascript('unsubBestNumber()');
  }
}
