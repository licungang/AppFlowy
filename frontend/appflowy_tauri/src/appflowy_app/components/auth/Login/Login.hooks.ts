import { useState } from 'react';
import { currentUserActions } from '../../../stores/reducers/current-user/slice';
import { useAppDispatch, useAppSelector } from '../../../stores/store';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.hooks';
import { nanoid } from 'nanoid';

export const useLogin = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const appDispatch = useAppDispatch();
  const currentUser = useAppSelector((state) => state.currentUser);
  const navigate = useNavigate();
  const { login } = useAuth();
  const [authErrorMessage, setAuthErrorMessage] = useState('');

  function onTogglePassword() {
    setShowPassword(!showPassword);
  }

  // reset error
  function _setEmail(v: string) {
    setAuthErrorMessage('');
    setEmail(v);
  }

  function _setPassword(v: string) {
    setAuthErrorMessage(false);
    setPassword(v);
  }

  async function onAutoSignInClick() {
    try {
      const fakeEmail = nanoid(8) + '@appflowy.io';
      const fakePassword = 'AppFlowy123@';
      const userProfile = await register(fakeEmail, fakePassword, 'Me');
      const { id, name, token } = userProfile;
      appDispatch(
        currentUserActions.updateUser({
          id: id,
          displayName: name,
          email: email,
          token: token,
          isAuthenticated: true,
        })
      );
      navigate('/');
    } catch (e) {
      setAuthErrorMessage(true);
    }
  }

  async function onSignInClick() {
    try {
      const userProfile = await login(email, password);
      const { id, name, token } = userProfile;
      appDispatch(
        currentUserActions.updateUser({
          id: id,
          displayName: name,
          email: email,
          token: token,
          isAuthenticated: true,
        })
      );
      navigate('/');
    } catch (e: any) {
      setAuthErrorMessage(e.message);
    }
  }

  return {
    showPassword,
    onTogglePassword,
    onSignInClick,
    onAutoSignInClick,
    email,
    setEmail: _setEmail,
    password,
    setPassword: _setPassword,
    authErrorMessage,
  };
};
