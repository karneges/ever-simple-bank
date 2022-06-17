const {expect} = require('chai');
const {
    setupTokenRoot,
    deployUser,
    deployBank,
    TokenWallet
} = require('./utils');
const {
    Bank,
    UserData
} = require('./bank');
const {} = locklift.utils;

let admin_user;
let root;
let userTokenWallet1;
let userTokenWallet2;
let user1;
let user2;
let user3;
const userInitialTokenBal = 10000;


describe('Setup contracts', async function () {
    this.timeout(30000000);

    describe('Tokens', async function () {
        it('Deploy admin', async function () {
            admin_user = await deployUser();
        });

        it('Deploy roots', async function () {
            root = await setupTokenRoot('Farm token', 'FT', admin_user);
        });
    });
    describe("deploy simpleBank", async function () {
        let bank;
        let bankTokenWallet;
        let userData1;
        let userData2;
        it('should deploy users', async function () {
            let users = [];
            for (const i of [1, 2, 3]) {
                const _user = await deployUser();
                users.push(_user);
            }
            [user1, user2, user3] = users;
        });
        it('Deploy users token wallets + mint tokens', async function () {
            userTokenWallet1 = await root.mint(userInitialTokenBal, user1);
            userTokenWallet2 = await root.mint(userInitialTokenBal, user2);
        });
        it('Check tokens minted to users', async function () {
            const balance1 = await userTokenWallet1.balance();
            const balance2 = await userTokenWallet2.balance();
            expect(balance1.toNumber()).to.be.equal(userInitialTokenBal, 'User ton token wallet empty');
            expect(balance2.toNumber()).to.be.equal(userInitialTokenBal, 'User ton token wallet empty');
        });
        it('should bank deployed', async function () {
            const deployedBank = await deployBank(root.address, root.address)
            bank = await Bank.fromAddress(deployedBank.address)
            bankTokenWallet = await TokenWallet.from_addr(await bank.getTokenWallet(), bank.address)
        });
        it('user should registered', async function () {
            await bank.registerUser(user1)
            await bank.registerUser(user2)
            await bank.registerUser(user3)
            const userDataAddress1 = await bank.getUserDataAddress(user1.address)
            console.log('UserData1 ', userDataAddress1)

            const userDataAddress2 = await bank.getUserDataAddress(user2.address)
            console.log('UserData2 ', userDataAddress2)

            userData1 = await UserData.fromAddress(userDataAddress1)
            userData2 = await UserData.fromAddress(userDataAddress2)
            const data1 = await userData1.getUserData()

            expect(data1.user).to.be.eq(user1.address, "user data related with different user")
            const data2 = await userData2.getUserData()
            expect(data2.user).to.be.eq(user2.address, "user data related with different user")
        });
        it('should deposited', async function () {
            const DEPOSIT_VALUE = 500
            await bank.deposit({
                depositValue: DEPOSIT_VALUE,
                userTokenWallet: userTokenWallet1,
                userData: userData1,
                bankTokenWallet: bankTokenWallet
            })
        });
        it('should withdraw', async function () {
            const WITHDRAW_VALUE = 500
            await bank.withdraw(user1, WITHDRAW_VALUE)
            const event = await bank.getEvents("Withdraw")
            expect(Number(event[0].value.amount)).to.be.eq(WITHDRAW_VALUE)
            expect(await bankTokenWallet.balance().then(res => res.toNumber())).to.be.eq(0)
            expect(await userData1.getUserData().then(res => res.amount.toNumber())).to.be.eq(0)
        });
        it('user should send money without bank', async function () {
            const SEND_AMOUNT = 500
            await bank.deposit({
                depositValue: SEND_AMOUNT,
                userTokenWallet: userTokenWallet1,
                userData: userData1,
                bankTokenWallet: bankTokenWallet
            })
            await userData1.sendToUser(user1, user2.address, SEND_AMOUNT)
            const [sendEvent, receiveEvent] = await Promise.all([userData1.getEvents('Send'), userData2.getEvents('Receive')]).then(res => res.map(el => el[0]))
            expect(sendEvent.value.toUser).to.be.eq(user2.address)
            expect(receiveEvent.value.fromUser).to.be.eq(user1.address)
            expect(sendEvent.value.amount).to.be.eq(receiveEvent.value.amount).and.eq(SEND_AMOUNT.toString())
            expect(await userData1.getUserData().then(res => res.amount.toNumber())).to.be.eq(0)
            expect(await userData2.getUserData().then(res => res.amount.toNumber())).to.be.eq(SEND_AMOUNT)
        });
        it('user2 should withdraw money from bank', async function () {
            const WITHDRAW_VALUE = 500
            await bank.withdraw(user2, WITHDRAW_VALUE)
            const event = await bank.getEvents("Withdraw")
            expect(Number(event[0].value.amount)).to.be.eq(WITHDRAW_VALUE)
            expect(await bankTokenWallet.balance().then(res => res.toNumber())).to.be.eq(0)
            expect(await userData2.getUserData().then(res => res.amount.toNumber())).to.be.eq(0)
            expect(await userTokenWallet2.balance().then(res => res.toNumber())).to.be.eq(userInitialTokenBal + WITHDRAW_VALUE)
        });
        it("user3 should receive value without wallet", async function () {
            const SEND_AMOUNT = 500
            await bank.deposit({
                depositValue: SEND_AMOUNT,
                userTokenWallet: userTokenWallet1,
                userData: userData1,
                bankTokenWallet: bankTokenWallet
            })
            await userData1.sendToUser(user1, user3.address, SEND_AMOUNT)
            await bank.withdraw(user3, SEND_AMOUNT)
            const event = await bank.getEvents("Withdraw")
            expect(Number(event[0].value.amount)).to.be.eq(SEND_AMOUNT)

            const userTokenWallet3 = await root.walletAddr(user3.address)
            expect(await userTokenWallet3.balance().then(res => res.toNumber())).to.be.eq(SEND_AMOUNT)
        });
    })

});
