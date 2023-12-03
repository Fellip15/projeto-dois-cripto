// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EnergiaSolar {
    event TransacaoCorrespondida(address comprador, address vendedor, uint256 quantidadeEnergia, uint256 preco);
    event PagamentoEnviado(address recebedor, uint256 valor);
    event PagamentoRecebido(address pagador, uint256 valor);

    struct Transacao {
        address payable comprador;
        address payable vendedor;
        uint256 quantidadeEnergia;
        uint256 preco;
        bool executado;
        bool correspondida;
        int256 idTransacaoCorrespondida;
    }

    struct Instalacao {
        address proprietario;
        uint256 capacidade;
        bool instalado;
    }

    Transacao[] public transacoes;
    Instalacao[] public instalacoes;

    // Apenas aceita transacoes que nao foram executadas
    modifier onlyNotExecuted(uint256 idTransacao) {
        require(!transacoes[idTransacao].executado, "Transacao ja executada");
        _;
    }

    // Apenas aceita transacoes que foram correspondidas
    modifier onlyCorresponded(uint256 idTransacao) {
        require(transacoes[idTransacao].correspondida, "Transacao nao correspondida");
        _;
    }

    // Apenas aceita instalacoes que foram instaladas (utilizar para um trabalho mais complexo
    modifier onlyInstalled(uint256 idInstalacao) {
        require(instalacoes[idInstalacao].instalado, "A instalacao nao esta concluida");
        _;
    }

    // Apenas aceita um pagamento minimo
    modifier requerPagamentoMinimo(uint256 minimo) {
        require(msg.value >= minimo, "Valor insuficiente enviado");
        _;
    }

    // Coloca uma ordem de compra de energia
    function colocarOrdemCompra(uint256 quantidade, uint256 preco) external payable {
        Transacao memory transacao = Transacao({
        comprador: payable(msg.sender), // comprador e quem enviou a mensagem
        vendedor: payable(address(0)),  // ainda nao ha vendedor
        quantidadeEnergia: quantidade,
        preco: preco,
        executado: false,               // ainda nao foi executada nem correspondida
        correspondida: false,
        idTransacaoCorrespondida: -1    // id da transacao que sera correspondida
        });

        transacoes.push(transacao);
    }

    function colocarOrdemVenda(uint256 quantidade, uint256 preco) external payable {
        Transacao memory transacao = Transacao({
        comprador: payable(address(0)),  // ainda nao ha comprador
        vendedor: payable(msg.sender),   // vendedor e quem enviou a mensagem
        quantidadeEnergia: quantidade,
        preco: preco,
        executado: false,
        correspondida: false,
        idTransacaoCorrespondida: -1
        });

        transacoes.push(transacao);
    }

    function instalarUnidade(uint256 capacidade) external payable requerPagamentoMinimo(capacidade * (1 ether)) {
        emit PagamentoRecebido(msg.sender, msg.value);

        Instalacao memory instalacao = Instalacao({
            proprietario: msg.sender,  // proprietario e quem enviou a mensagem
            capacidade: capacidade,    // preco sera calculado com base na capacidade
            instalado: true
        });

        instalacoes.push(instalacao);
    }

    function corresponderOrdens(uint256 idTransacao) external onlyNotExecuted(idTransacao) {
        Transacao storage ordemCompra = transacoes[idTransacao];
        require(ordemCompra.comprador != address(0), "ID de transacao invalido");

        for (uint256 i = 0; i < transacoes.length; i++) {
            Transacao storage ordemVenda = transacoes[i];

            if (ordemVenda.vendedor != address(0) // nao e uma ordem de compra
                    && !ordemVenda.correspondida      // ainda nao foi correspondida
                    && ordemVenda.quantidadeEnergia == ordemCompra.quantidadeEnergia // a quantidade de venda e compra sao iguais
                    && ordemVenda.preco <= ordemCompra.preco) {  // o preco para venda ta menor ou igual da compra

                ordemCompra.vendedor = ordemVenda.vendedor;
                ordemVenda.comprador = ordemCompra.comprador;
                ordemCompra.correspondida = true;
                ordemCompra.idTransacaoCorrespondida = int256(i);
                ordemVenda.correspondida = true;
                ordemVenda.idTransacaoCorrespondida = int256(idTransacao);
                ordemCompra.preco = ordemVenda.preco;
                emit TransacaoCorrespondida(ordemCompra.comprador, ordemVenda.vendedor, ordemCompra.quantidadeEnergia, ordemCompra.preco);
                break;
            }
        }
    }

    function executarTransacao(uint256 idTransacao) external payable onlyCorresponded(idTransacao) onlyNotExecuted(idTransacao) {
        Transacao storage transacao = transacoes[idTransacao];
        require(transacao.comprador == msg.sender, "Nao autorizado"); // apenas o comprador pode executar pois ele precisa enviar o dinheiro

        uint256 valorTotal =  transacao.quantidadeEnergia * transacao.preco;
        require(transacao.quantidadeEnergia * transacao.preco < msg.value, "Dinheiro enviado insuficiente");
        (bool sucesso, ) = transacao.vendedor.call{value: valorTotal}(""); // faz o envio do dinheiro
        require(sucesso, "Transacao falhou");

        transacao.executado = true;
        transacoes[uint256(transacao.idTransacaoCorrespondida)].executado = true; // coloca as transacoes como executadas
        
        emit PagamentoEnviado(transacao.vendedor, valorTotal); // emite o pagamento para informacao
    }

    // funcoes auxiliares de visualizacao de dados
    function obterNumeroTransacoes() external view returns (uint256) {
        return transacoes.length;
    }

    function obterTransacao(uint256 idTransacao) external view returns (address, address, uint256, uint256, bool) {
        Transacao storage transacao = transacoes[idTransacao];
        return (transacao.comprador, transacao.vendedor, transacao.quantidadeEnergia, transacao.preco, transacao.executado);
    }

    function obterNumeroInstalacoes() external view returns (uint256) {
        return instalacoes.length;
    }

    function obterInstalacao(uint256 idInstalacao) external view onlyInstalled(idInstalacao) returns (address, uint256, bool) {
        Instalacao storage instalacao = instalacoes[idInstalacao];
        return (instalacao.proprietario, instalacao.capacidade, instalacao.instalado);
    }
}
