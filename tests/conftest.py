import pytest


@pytest.fixture(scope="function", autouse=True)
def shared_setup(fn_isolation):
    pass


@pytest.fixture()
def minter(accounts):
    return accounts.at("0x2F0b23f53734252Bda2277357e97e1517d6B042A", force=True)


@pytest.fixture()
def giftee(accounts):
    return accounts[1]


@pytest.fixture()
def token(interface):
    return interface.ERC20("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")


@pytest.fixture()
def controller(accounts):
    return accounts[0]


@pytest.fixture()
def ygift(yGift, controller):
    return yGift.deploy({"from": controller})