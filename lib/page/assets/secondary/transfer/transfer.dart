import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polka_wallet/common/regInputFormatter.dart';
import 'package:polka_wallet/store/account.dart';
import 'package:polka_wallet/store/settings.dart';
import 'package:polka_wallet/utils/format.dart';
import 'package:polka_wallet/utils/i18n/index.dart';

class Transfer extends StatefulWidget {
  const Transfer(this.accountStore, this.settingsStore);

  final AccountStore accountStore;
  final SettingsStore settingsStore;

  @override
  _TransferState createState() => _TransferState(accountStore, settingsStore);
}

class _TransferState extends State<Transfer> {
  _TransferState(this.accountStore, this.settingsStore);

  final AccountStore accountStore;
  final SettingsStore settingsStore;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _addressCtrl = new TextEditingController();
  final TextEditingController _amountCtrl = new TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final String args = ModalRoute.of(context).settings.arguments;
    if (args != null) {
      setState(() {
        _addressCtrl.text = args;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> dic = I18n.of(context).assets;
    String symbol = settingsStore.networkState.tokenSymbol;
    int decimals = settingsStore.networkState.tokenDecimals;

    String balance = Fmt.balance(accountStore.assetsState.balance);

    return Scaffold(
      appBar: AppBar(
        title: Text('${dic['transfer']} $symbol'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Image.asset('assets/images/assets/Menu_scan.png'),
            onPressed: () async {
              var to = await Navigator.of(context).pushNamed('/account/scan');
              setState(() {
                _addressCtrl.text = to;
              });
            },
          )
        ],
      ),
      body: Builder(builder: (BuildContext context) {
        return Column(
          children: <Widget>[
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: TextFormField(
                        decoration: InputDecoration(
                            hintText: dic['address'],
                            labelText: dic['address'],
                            suffix: IconButton(
                              icon: Image.asset(
                                  'assets/images/profile/address.png'),
                              onPressed: () async {
                                var to = await Navigator.of(context)
                                    .pushNamed('/contacts/list');
                                setState(() {
                                  _addressCtrl.text = to;
                                });
                              },
                            )),
                        controller: _addressCtrl,
                        validator: (v) {
                          return Fmt.isAddress(v.trim())
                              ? null
                              : dic['address.error'];
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: TextFormField(
                        decoration: InputDecoration(
                          hintText: dic['amount'],
                          labelText:
                              '${dic['amount']} (${dic['balance']}: $balance)',
                        ),
                        inputFormatters: [
                          RegExInputFormatter.withRegex(
                              '^[0-9]{0,6}(\\.[0-9]{0,$decimals})?\$')
                        ],
                        controller: _amountCtrl,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v.isEmpty) {
                            return dic['amount.error'];
                          }
                          if (double.parse(v.trim()) >=
                              double.parse(balance) - 0.02) {
                            return dic['amount.low'];
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                          'TransferFee: ${settingsStore.transferFeeView} $symbol',
                          style:
                              TextStyle(fontSize: 16, color: Colors.black54)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'CreationFee: ${settingsStore.creationFeeView} $symbol',
                          style:
                              TextStyle(fontSize: 16, color: Colors.black54)),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: RaisedButton(
                      color: Colors.pink,
                      padding: EdgeInsets.all(16),
                      child: Text(
                        I18n.of(context).assets['make'],
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () {
                        if (_formKey.currentState.validate()) {
                          Navigator.of(context).pushNamed(
                              '/assets/transfer/confirm',
                              arguments: {
                                "to": _addressCtrl.text.trim(),
                                "amount": _amountCtrl.text.trim(),
                              });
                        }
                      },
                    ),
                  ),
                ),
              ],
            )
          ],
        );
      }),
    );
  }
}
