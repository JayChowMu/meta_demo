import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:walletconnect_secure_storage/walletconnect_secure_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

const chains = [
  {'chainId': 421613, 'chainType': 'arbitrum', 'rpcUrl': 'https://endpoints.omniatech.io/v1/arbitrum/goerli/public'},
  {'chainId': 80001, 'chainType': 'polygon', 'rpcUrl': 'https://rpc-mumbai.maticvigil.com'}
];

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('current chain: $_curChain'),
            Text('current chain id: $_curChainId'),
            Container(height: 40),
            // TextButton(onPressed: connect, child: Text('Connect metamask')),
            TextButton(
                onPressed: () async {
                  final res = await switchChain(chains[0]);
                  if (res) {
                    setState(() {
                      _curChain = chains[0]['chainType'] as String?;
                    });
                  }
                },
                child: Text('Switch to arbitrum')),
            TextButton(
                onPressed: () async {
                  final res = await switchChain(chains[1]);
                  if (res) {
                    setState(() {
                      _curChain = chains[1]['chainType'] as String?;
                    });
                  }
                },
                child: Text('Switch to polygon')),
          ],
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  WalletConnect? _connector;
  WalletConnectSession? _session;
  var chainIndex = 0;
  String? _curChain;
  int _curChainId = -1;

  Future connect() async {
    final sessionStorage = WalletConnectSecureStorage();
    _session = await sessionStorage.getSession();

    _connector = WalletConnect(
      session: _session,
      sessionStorage: sessionStorage,
      bridge: 'https://bridge.walletconnect.org',
      clientMeta: const PeerMeta(
        name: 'Demo',
        description: 'Demo App',
        url: 'https://www.google.com',
      ),
    );

    _connector!.on('session_update', (e) {
      if (e is WCSessionUpdateResponse) {
        setState(() {
          _curChainId = e.chainId;
        });
      }
    });

    print('debug ${_connector?.connected}');
    if (_connector != null && !_connector!.connected) {
      final status = await _connector!.createSession(
          chainId: 1,
          onDisplayUri: (uriStr) async {
            uriStr = 'metamask://wc?uri=$uriStr';
            final uri = Uri.parse(uriStr);
            final walletInstalled = await canLaunchUrl(uri);
            if (walletInstalled) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              print('Error: Metamask app not installed.');
            }
          });
      print('Connected: ${status.accounts[0]}');
      _session = _connector!.session;
    }
  }

  Future switchChain(Map<String, dynamic> params) async {
    if (_connector == null || !_connector!.connected) {
      await connect();
    }
    final int chainId = params['chainId'];

    launchUrl(Uri.parse('metamask://app'));
    try {
      await Future.delayed(const Duration(seconds: 1));
      await _connector!.sendCustomRequest(method: 'wallet_switchEthereumChain', params: [
        {
          'chainId': '0x${chainId.toRadixString(16)}',
        },
      ]);
    } catch (e) {
      if ('$e'.contains('-32000')) {
        return _addChain(params);
      } else {
        print('Error: $e');
      }
      return false;
    }
    return true;
  }

  Future _addChain(Map<String, dynamic> params) async {
    if (_connector == null || !_connector!.connected) {
      await connect();
    }
    final int chainId = params['chainId'];
    final pType = params['chainType'];
    final pRpcUrl = params['rpcUrl'];

    launchUrl(Uri.parse('metamask://app'));
    try {
      await Future.delayed(const Duration(seconds: 1));
      await _connector!.sendCustomRequest(method: 'wallet_addEthereumChain', params: [
        {
          'chainId': '0x${chainId.toRadixString(16)}',
          'chainName': pType,
          'rpcUrls': [pRpcUrl],
        },
      ]);
    } catch (e) {
      print('Error: $e');
      return false;
    }
    return true;
  }
}
